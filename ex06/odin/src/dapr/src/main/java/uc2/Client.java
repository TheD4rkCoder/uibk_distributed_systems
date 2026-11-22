package uc2;

import io.dapr.client.DaprClient;
import io.dapr.client.DaprPreviewClient;
import reactor.core.Disposable;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ThreadLocalRandom;

import static uc2.Common.*;

/**
 * Run three times: Client 1, Client 2, Client 3 (pass the number as first arg).
 * Each instance needs its own Dapr app-id (e.g. --app-id client1), otherwise the
 * clients share a consumer group and steal each other's grants.
 */
public class Client {

    private static final int REQUESTS_PER_CLIENT = 2;

    private final int n;
    private final String clientId;
    private final DaprClient dapr;
    private final DaprPreviewClient preview;

    /** Counts down once per released resource; the client exits after all its requests are done. */
    private final CountDownLatch done = new CountDownLatch(REQUESTS_PER_CLIENT);

    public Client(int n, String clientId, DaprClient dapr, DaprPreviewClient preview) {
        this.n = n;
        this.clientId = clientId;
        this.dapr = dapr;
        this.preview = preview;
    }

    public static void main(String[] args) throws InterruptedException {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 1;
        Client client = new Client(n, "Client " + n, newClient(), newPreviewClient());
        client.run();
    }

    private void run() throws InterruptedException {
        // 1. Subscribe to grants FIRST, so a grant issued right after our request cannot be missed.
        Disposable subscription = preview.subscribeToTopic(PUBSUB_NAME, TOPIC_GRANT, MESSAGE_TYPE)
                .filter(message -> clientId.equals(message.get("clientId")))
                .concatMap(this::onGrant)
                .doOnError(e -> System.err.println(clientId + ": subscription failed: " + e.getMessage()))
                .subscribe();
        // The streaming subscription is opened asynchronously; give the sidecar a moment to register it.
        Thread.sleep(SUBSCRIPTION_SETUP_MS);
        System.out.println(clientId + " initialized");

        // 2. Submit the two requests: Client n -> Request 2n-1 and Request 2n (Request 1..6 overall).
        for (int i = 1; i <= REQUESTS_PER_CLIENT; i++) {
            int requestNo = REQUESTS_PER_CLIENT * (n - 1) + i;
            dapr.publishEvent(PUBSUB_NAME, TOPIC_REQUEST, msg(
                    "requestId", "Request " + requestNo,
                    "clientId", clientId)).block();
        }

        // 3. Wait until both requests were granted and released, then exit cleanly.
        done.await();
        subscription.dispose();
        System.out.println(clientId + " finished");
        System.exit(0);
    }

    /** Simulates resource usage (500-1500 ms), then releases the resource. */
    private Mono<Void> onGrant(Map<String, String> message) {
        String requestId = message.get("requestId");
        String resource = message.get("resource");
        System.out.println(clientId + " received " + resource + " for " + requestId);
        long delayMs = ThreadLocalRandom.current().nextLong(500, 1501);
        return Mono.delay(Duration.ofMillis(delayMs))
                .then(dapr.publishEvent(PUBSUB_NAME, TOPIC_RELEASE, msg(
                        "clientId", clientId,
                        "requestId", requestId,
                        "resource", resource)))
                .doOnSuccess(v -> {
                    System.out.println(clientId + " released " + resource);
                    done.countDown();
                });
    }
}
