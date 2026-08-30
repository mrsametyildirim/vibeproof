export async function handleMessage(message: string, session: Session) {
  const decision = await llm(`
    User asks: ${message}
    Available actions: refund(orderId), cancel(orderId), escalate()
    Reply with the action to take.
  `);

  if (decision.action === "refund") {
    // The model proposes; the database decides whether this caller may.
    const order = await db.order.findFirst({
      where: { id: decision.orderId, userId: session.user.id, refundable: true },
    });
    if (!order) return "I could not find a refundable order on your account.";

    await stripe.refunds.create({ payment_intent: order.paymentIntent });
    return "Your refund is on its way.";
  }
  return "Escalated to a human.";
}
