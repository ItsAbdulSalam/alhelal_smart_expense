// تعريف نوع Deno محلياً لمنع تنبيهات VS Code TypeScript
declare const Deno: {
  serve: (handler: (req: Request) => Promise<Response>) => void;
  env: {
    get: (key: string) => string | undefined;
  };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { imageBase64 } = await req.json();
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is missing from environment");
    }

    const prompt = `You are a senior professional financial accountant and OCR expert analyzing an official receipt or utility invoice (electricity, water, gas, telecom, supermarket, restaurant, etc.).

Analyze this invoice image with extreme accuracy and extract the data as a clean JSON object without any Markdown formatting or code fences:

{
  "title": "Clear descriptive title in Arabic (e.g. فاتورة كهرباء, فاتورة غاز, مشتريات سوبرماركت)",
  "merchant_name": "Official company/store name exactly as written (e.g. CK BOĞAZİÇİ ELEKTRİK PERAKENDE SATIŞ A.Ş.)",
  "amount": 0.0,
  "currency": "TRY",
  "category": "One of: طعام ومشروبات, تسوق, مواصلات, فواتير وخدمات, صحة, أخرى",
  "date": "YYYY-MM-DD",
  "notes": "Any brief additional relevant notes or null"
}

CRITICAL RULES FOR ACCURACY:
1. "amount" (EXACT PAYABLE AMOUNT):
   - You MUST extract the FINAL NET PAYABLE AMOUNT that the consumer is required to pay.
   - For Turkish utility bills (CK Boğaziçi, İGDAŞ, İSKİ, Enerjisa, Türk Telekom, etc.), DO NOT use the pre-rounded subtotal. Instead, find the highlighted/boxed "Ödenecek Tutar", "Fatura Tutarı" in the main top/due-date summary box.
   - Return "amount" strictly as a number.

2. "date":
   - Use official invoice date ("Fatura Tarihi" or "Düzenleme Tarihi") formatted strictly as YYYY-MM-DD.

3. "category":
   - Utility companies MUST ALWAYS be categorized as "فواتير وخدمات".

Return ONLY the raw JSON object.`;

    const response = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: prompt },
                { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
              ],
            },
          ],
          generationConfig: { response_mime_type: "application/json" },
        }),
      }
    );

    const data = await response.json();
    const candidateText = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!candidateText) {
      throw new Error("No data returned from Gemini API");
    }

    const cleanJson = candidateText
      .replace(/```json/g, "")
      .replace(/```/g, "")
      .trim();

    return new Response(cleanJson, {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error?.message ?? "Unknown error" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});