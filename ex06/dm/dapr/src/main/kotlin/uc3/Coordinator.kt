package uc3

// CLARIFICATION: I used an LLM to generate template code for me to fill out!

import io.dapr.client.DaprClient
import io.dapr.client.DaprClientBuilder
import io.dapr.client.DaprPreviewClient
import reactor.core.Disposable
import reactor.core.publisher.Flux
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.system.exitProcess

private enum class OrderService { INVENTORY, PAYMENT }

private data class ServiceResult(
    val service: OrderService,
    val message: OrderMessage,
)

fun main() {
    val daprClient: DaprClient = newClient()
    val previewClient: DaprPreviewClient = DaprClientBuilder().buildPreviewClient()

    val completed: Boolean = OrderCoordinator(daprClient, previewClient).run()

    previewClient.close()
    daprClient.close()
    exitProcess(if (completed) 0 else 1)
}

private class OrderCoordinator(
    private val daprClient: DaprClient,
    private val previewClient: DaprPreviewClient,
) {
    private val orderIds: List<String> =
        (1..6).map { orderNumber: Int -> "Order $orderNumber" }

    private val orderStates: MutableMap<String, String> =
        orderIds.associateWith { "PENDING" }.toMutableMap()

    private val stateLock: Any = Any()
    private val allOrdersFinished: CountDownLatch = CountDownLatch(1)
    private var summaryPrinted: Boolean = false

    fun run(): Boolean {
        saveOrderStates()

        val resultSubscription: Disposable = startResultSubscriptions()
        try {
            Thread.sleep(500)
            submitAllOrders()
            awaitAllOrders()
        } finally {
            resultSubscription.dispose()
        }

        return summaryPrinted
    }

    // Flux class is a reactive stream that can emit multiple values over time
    // Disposable class is a handle to cancel the subscription to the stream
    // LLM gave me these 'primitives' when I asked for potentially needed concepts and code
    // but I couldn't think of a use other than for outputs...
    private fun startResultSubscriptions(): Disposable {
        val inventoryResults: Flux<ServiceResult> = previewClient
            .subscribeToTopic(PUBSUB_NAME, TOPIC_INVENTORY_RESULT, ORDER_MESSAGE_TYPE)
            .map { message: OrderMessage -> ServiceResult(OrderService.INVENTORY, message) }

        val paymentResults: Flux<ServiceResult> = previewClient
            .subscribeToTopic(PUBSUB_NAME, TOPIC_PAYMENT_RESULT, ORDER_MESSAGE_TYPE)
            .map { message: OrderMessage -> ServiceResult(OrderService.PAYMENT, message) }

        val mergedResults: Flux<ServiceResult> = Flux.merge(inventoryResults, paymentResults)

        return mergedResults
            .doOnNext { result: ServiceResult -> recordResult(result) }
            .doOnError { error: Throwable -> recordSubscriptionError(error) }
            .subscribe()
    }

    private fun submitAllOrders(): Unit {
        synchronized(stateLock) {
            orderIds.forEach { orderId: String ->
                orderStates[orderId] = "CHECKING"
                saveOrderStates()
                publishInventoryRequest(orderId)
            }
        }
    }

    private fun recordResult(result: ServiceResult): Unit {
        val orderId: String = result.message["orderId"] ?: return
        val succeeded: Boolean = result.message["success"]?.toBooleanStrictOrNull() ?: return

        synchronized(stateLock) {
            // this form of switch case is interesting in my opinion (why not name it the same as everyone else?)
            when (result.service) {
                OrderService.INVENTORY -> recordInventoryResult(orderId, succeeded)
                OrderService.PAYMENT -> recordPaymentResult(orderId, succeeded)
            }

            printOrderStates()
            finishIfAllOrdersAreTerminal()
        }
    }

    private fun recordInventoryResult(orderId: String, approved: Boolean): Unit {
        if (orderStates[orderId] != "CHECKING") {
            println("coordinator: should never happen (in recordInventoryResult)")
            return
        }

        if (approved) {
            orderStates[orderId] = "PAYMENT"
            saveOrderStates()
            publishPaymentRequest(orderId)
            println("coordinator: $orderId approved by inventory; payment requested")
        } else {
            orderStates[orderId] = "REJECTED"
            saveOrderStates()
            println("coordinator: $orderId rejected by inventory")
        }
    }

    private fun recordPaymentResult(orderId: String, paymentSucceeded: Boolean): Unit {
        if (orderStates[orderId] != "PAYMENT") {
            println("coordinator: should never happen (in recordPaymentResult)")
            return
        }

        orderStates[orderId] = if (paymentSucceeded) "COMPLETED" else "REJECTED"
        saveOrderStates()
        println("coordinator: $orderId payment ${if (paymentSucceeded) "succeeded" else "failed"}")
    }

    private fun finishIfAllOrdersAreTerminal(): Unit {
        val allOrdersAreTerminal: Boolean =
            orderStates.values.all { state: String -> isTerminal(state) }

        if (summaryPrinted || !allOrdersAreTerminal) {
            return
        }

        summaryPrinted = true
        println("coordinator: final summary ${orderStates.toSortedMap()}")
        allOrdersFinished.countDown()
    }

    private fun awaitAllOrders(): Unit {
        if (!allOrdersFinished.await(30, TimeUnit.SECONDS)) {
            System.err.println("coordinator: timed out waiting for all orders")
        }
    }

    private fun saveOrderStates(): Unit {
        daprClient
            .saveState(STATE_STORE_NAME, ORDER_STATE_KEY, orderStates)
            .block()
    }

    private fun publishInventoryRequest(orderId: String): Unit {
        daprClient
            .publishEvent(PUBSUB_NAME, TOPIC_INVENTORY_REQUEST, orderMessage(orderId))
            .block()
        println("coordinator: submitted $orderId")
    }

    private fun publishPaymentRequest(orderId: String): Unit {
        daprClient
            .publishEvent(PUBSUB_NAME, TOPIC_PAYMENT_REQUEST, orderMessage(orderId))
            .block()
    }

    private fun printOrderStates(): Unit {
        println("coordinator: order states ${orderStates.toSortedMap()}")
    }

    private fun recordSubscriptionError(error: Throwable): Unit {
        System.err.println("coordinator: subscription failed: ${error.message}")
        allOrdersFinished.countDown()
    }

    private fun isTerminal(state: String): Boolean =
        state == "COMPLETED" || state == "REJECTED"
}
