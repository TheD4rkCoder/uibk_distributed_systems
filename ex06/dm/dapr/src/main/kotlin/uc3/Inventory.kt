package uc3

import io.dapr.client.DaprClient
import io.dapr.client.DaprClientBuilder
import io.dapr.client.DaprPreviewClient
import reactor.core.publisher.Mono
import java.time.Duration
import kotlin.random.Random

fun main() {
    val daprClient: DaprClient = newClient()
    val previewClient: DaprPreviewClient = DaprClientBuilder().buildPreviewClient()

    previewClient
        .subscribeToTopic(PUBSUB_NAME, TOPIC_INVENTORY_REQUEST, ORDER_MESSAGE_TYPE)
        .concatMap { request: OrderMessage -> handleInventoryRequest(daprClient, request) }
        .doOnError { error: Throwable ->
            System.err.println("inventory: subscription failed: ${error.message}")
        }
        .blockLast()
}

private fun handleInventoryRequest(
    daprClient: DaprClient,
    request: OrderMessage,
): Mono<Void> {
    val orderId: String = request["orderId"]
        ?: return Mono.empty()

    val approved: Boolean = orderId != "Order 3"
    val delayMilliseconds: Long = Random.nextLong(300, 801)

    println("inventory: received request for $orderId")

    // needed the help of LLM to figure out:
    // returning mono doens't block the thread, and logically stops
    // concatMap from continuing until the mono completes
    // (concatMap executes incoming requests sequentially; essentially 
    // acts as a queue)
    return Mono
        .delay(Duration.ofMillis(delayMilliseconds))
        .then(
            daprClient.publishEvent(
                PUBSUB_NAME,
                TOPIC_INVENTORY_RESULT,
                orderMessage(orderId, "success" to approved.toString()),
            ),
        )
}
