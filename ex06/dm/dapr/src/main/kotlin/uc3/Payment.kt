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
        .subscribeToTopic(PUBSUB_NAME, TOPIC_PAYMENT_REQUEST, ORDER_MESSAGE_TYPE)
        .concatMap { request: OrderMessage -> handlePaymentRequest(daprClient, request) }
        .doOnError { error: Throwable ->
            System.err.println("payment: subscription failed: ${error.message}")
        }
        .blockLast()
}

private fun handlePaymentRequest(
    daprClient: DaprClient,
    request: OrderMessage,
): Mono<Void> {
    val orderId: String = request["orderId"]
        ?: return Mono.empty()

    val paymentSucceeded: Boolean = orderId != "Order 5"
    val delayMilliseconds: Long = Random.nextLong(300, 801)

    println("payment: received request for $orderId")

    // tecnically completely different from my CSML implementation: see comment in Inventory.kt
    return Mono
        .delay(Duration.ofMillis(delayMilliseconds))
        .then(
            daprClient.publishEvent(
                PUBSUB_NAME,
                TOPIC_PAYMENT_RESULT,
                orderMessage(orderId, "success" to paymentSucceeded.toString()),
            ),
        )
}
