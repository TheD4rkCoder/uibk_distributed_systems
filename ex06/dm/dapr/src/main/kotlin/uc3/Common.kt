package uc3

import io.dapr.client.DaprClient
import io.dapr.client.DaprClientBuilder
import io.dapr.utils.TypeRef

// CLARIFICATION: I used an LLM to generate template code for me to fill out!

const val PUBSUB_NAME = "pubsub"
const val STATE_STORE_NAME = "statestore"
const val ORDER_STATE_KEY = "orders"

const val TOPIC_INVENTORY_REQUEST = "inventory-request"
const val TOPIC_INVENTORY_RESULT = "inventory-result"
const val TOPIC_PAYMENT_REQUEST = "payment-request"
const val TOPIC_PAYMENT_RESULT = "payment-result"

/** Flat string map: Dapr's default Jackson serializer handles this without a Kotlin module. */
typealias OrderMessage = Map<String, String>

val ORDER_MESSAGE_TYPE: TypeRef<OrderMessage> = object : TypeRef<OrderMessage>() {}

/** Builds a client, but first waits until `dapr run` has injected a reachable sidecar. */
fun newClient(): DaprClient =
    DaprClientBuilder().build().also { client: DaprClient ->
        client.waitForSidecar(10_000).block()
    }

fun orderMessage(orderId: String, vararg extra: Pair<String, String>): OrderMessage =
    mapOf("orderId" to orderId) + extra
