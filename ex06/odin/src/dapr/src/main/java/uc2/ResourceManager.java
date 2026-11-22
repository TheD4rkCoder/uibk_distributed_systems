package uc2;

import io.dapr.client.DaprClient;
import io.dapr.client.DaprPreviewClient;
import reactor.core.publisher.Flux;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.locks.ReentrantLock;

import static uc2.Common.*;

public class ResourceManager {

    private final DaprClient dapr;
    private final DaprPreviewClient preview;

    /** Single-instance coordination lock (allowed by requirement 3). */
    private final ReentrantLock lock = new ReentrantLock();

    /** In-memory view of the state; every change is also persisted to the Dapr state store. */
    private final Map<String, ResourceStatus> resources = new LinkedHashMap<>();
    private final Map<String, RequestStatus> requests = new LinkedHashMap<>();
    /** Who issued each request, and which resource a granted request holds. */
    private final Map<String, String> requestClient = new HashMap<>();
    private final Map<String, String> requestResource = new HashMap<>();
    /** FIFO queue of pending request IDs. */
    private final Deque<String> pending = new ArrayDeque<>();

    private boolean allCompletedReported = false;

    public ResourceManager(DaprClient dapr, DaprPreviewClient preview) {
        this.dapr = dapr;
        this.preview = preview;
    }

    public static void main(String[] args) {
        ResourceManager manager = new ResourceManager(newClient(), newPreviewClient());
        manager.init();
        manager.run();
    }

    private void init() {
        for (String resource : new String[] {"Resource 1", "Resource 2"}) {
            setResource(resource, ResourceStatus.AVAILABLE);
        }
        System.out.println("Resource Manager initialized");
    }

    /** Subscribes to request + release topics and blocks forever. */
    private void run() {
        Flux<Map<String, String>> requestsFlux =
                preview.subscribeToTopic(PUBSUB_NAME, TOPIC_REQUEST, MESSAGE_TYPE);
        Flux<Map<String, String>> releasesFlux =
                preview.subscribeToTopic(PUBSUB_NAME, TOPIC_RELEASE, MESSAGE_TYPE);

        Flux.merge(
                requestsFlux.doOnNext(this::onRequest),
                releasesFlux.doOnNext(this::onRelease)
        ).doOnError(e -> System.err.println("manager: subscription failed: " + e.getMessage()))
         .blockLast();
    }

    private void onRequest(Map<String, String> message) {
        lock.lock();
        try {
            String requestId = message.get("requestId");
            String clientId = message.get("clientId");
            if (requestId == null || clientId == null) {
                System.err.println("manager: invalid request message: " + message);
                return;
            }
            if (requests.containsKey(requestId)) {
                System.err.println("manager: duplicate requestId: " + requestId);
                return;
            }
            requestClient.put(requestId, clientId);

            Optional<String> free = findAvailableResource();
            if (free.isPresent()) {
                grantRequest(requestId, free.get());
            } else {
                // No available resources, queue the request (FIFO)
                setRequest(requestId, RequestStatus.PENDING);
                pending.addLast(requestId);
                System.out.println(requestId + " pending");
            }
        } finally {
            lock.unlock();
        }
    }

    private void onRelease(Map<String, String> message) {
        lock.lock();
        try {
            String requestId = message.get("requestId");
            String clientId = message.get("clientId");
            if (requestId == null || clientId == null) {
                System.err.println("manager: invalid release message: " + message);
                return;
            }
            // Only a GRANTED request held by this very client may release its resource.
            if (requests.get(requestId) != RequestStatus.GRANTED) {
                System.err.println("manager: release for non-granted request: " + requestId);
                return;
            }
            if (!clientId.equals(requestClient.get(requestId))) {
                System.err.println("manager: " + clientId + " does not own " + requestId);
                return;
            }
            // Use the resource we recorded on grant, not whatever the client claims.
            String resource = requestResource.remove(requestId);

            setResource(resource, ResourceStatus.AVAILABLE);
            setRequest(requestId, RequestStatus.COMPLETED);
            System.out.println(clientId + " released " + resource);

            // Automatically hand the freed resource to the oldest pending request.
            String next = pending.pollFirst();
            if (next != null) {
                grantRequest(next, resource);
            }

            checkAllCompleted();
        } finally {
            lock.unlock();
        }
    }

    /** Must be called with the lock held and the resource AVAILABLE. */
    private void grantRequest(String requestId, String resource) {
        String clientId = requestClient.get(requestId);
        setResource(resource, ResourceStatus.RESERVED);
        setRequest(requestId, RequestStatus.GRANTED);
        requestResource.put(requestId, resource);
        System.out.println(resource + " granted to " + clientId);
        publish(TOPIC_GRANT, msg(
                "requestId", requestId,
                "clientId", clientId,
                "resource", resource));
    }

    private Optional<String> findAvailableResource() {
        return resources.entrySet().stream()
                .filter(e -> e.getValue() == ResourceStatus.AVAILABLE)
                .map(Map.Entry::getKey)
                .findFirst();
    }

    private void checkAllCompleted() {
        long completed = requests.values().stream()
                .filter(s -> s == RequestStatus.COMPLETED)
                .count();
        if (!allCompletedReported && completed == TOTAL_REQUESTS) {
            allCompletedReported = true;
            System.out.println("All resource requests completed");
        }
    }

    // state helpers: update memory and the Dapr state store together

    private void setResource(String resource, ResourceStatus status) {
        resources.put(resource, status);
        saveState("resource:" + resource, status);
    }

    private void setRequest(String requestId, RequestStatus status) {
        requests.put(requestId, status);
        saveState("request:" + requestId, msg(
                "status", status.name(),
                "clientId", requestClient.get(requestId)));
    }

    private void saveState(String key, Object value) {
        dapr.saveState(STATE_STORE_NAME, key, value).block();
    }

    private void publish(String topic, Map<String, String> message) {
        dapr.publishEvent(PUBSUB_NAME, topic, message).block();
    }
}
