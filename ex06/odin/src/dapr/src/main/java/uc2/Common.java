package uc2;

import io.dapr.client.DaprClient;
import io.dapr.client.DaprClientBuilder;
import io.dapr.client.DaprPreviewClient;
import io.dapr.utils.TypeRef;

import java.util.HashMap;
import java.util.Map;

/** Shared constants and helpers for the resource manager and the clients. */
public final class Common {

    private Common() {}

    // Dapr component names (must match metadata.name in config/*.yaml)
    public static final String PUBSUB_NAME = "pubsub";
    public static final String STATE_STORE_NAME = "statestore";

    // Topics
    public static final String TOPIC_REQUEST = "resource-request"; // client  -> manager
    public static final String TOPIC_GRANT   = "resource-grant";   // manager -> client
    public static final String TOPIC_RELEASE = "resource-release"; // client  -> manager

    /** Three clients x two requests each (Request 1..6). */
    public static final int TOTAL_REQUESTS = 6;

    /** Time a client waits after opening its streaming subscription before publishing requests. */
    public static final long SUBSCRIPTION_SETUP_MS = 1_000;

    // Statuses
    public enum ResourceStatus { AVAILABLE, RESERVED }
    public enum RequestStatus { PENDING, GRANTED, COMPLETED }

    /** Pub/sub payload: a flat String map, which Dapr's default Jackson serializer handles out of the box. */
    public static final TypeRef<Map<String, String>> MESSAGE_TYPE = new TypeRef<>() {};

    /** Builds a client and waits until the `dapr run` sidecar is reachable. */
    public static DaprClient newClient() {
        DaprClient client = new DaprClientBuilder().build();
        client.waitForSidecar(10_000).block();
        return client;
    }

    /** Client used for streaming subscriptions (no HTTP server needed). */
    public static DaprPreviewClient newPreviewClient() {
        return new DaprClientBuilder().buildPreviewClient();
    }

    /** Small helper for building a message: msg("requestId", "Request 1", "clientId", "Client 1"). */
    public static Map<String, String> msg(String... keyValues) {
        Map<String, String> m = new HashMap<>();
        for (int i = 0; i + 1 < keyValues.length; i += 2) {
            m.put(keyValues[i], keyValues[i + 1]);
        }
        return m;
    }
}
