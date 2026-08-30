export async function handleMessage(message: string, order: Order) {
  const decision = await llm(`
    User asks: ${message}
    Available actions: refund(orderId), cancel(orderId), escalate()
    Reply with the action to take.
  `);

  if (decision.action === "refund") {
    await stripe.refunds.create({ payment_intent: order.paymentIntent });
    return "Your refund is on its way.";
  }
  return "Escalated to a human.";
}
