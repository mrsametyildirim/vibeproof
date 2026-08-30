export async function storeInvoice(pdf: Blob, invoiceId: string) {
  return supabase.storage.from("invoices").upload(`${invoiceId}.pdf`, pdf);
}
