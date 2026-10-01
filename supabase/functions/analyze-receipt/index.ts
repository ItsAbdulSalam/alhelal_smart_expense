declare const Deno: {
  serve: (handler: (req: Request) => Promise<Response>) => void;
  env: {
    get: (key: string) => string | undefined;
  };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-goog-api-key",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { imageBase64 } = await req.json();
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is not configured in Supabase Secrets");
    }

    if (!imageBase64) {
      throw new Error("No image data provided");
    }

    const cleanedBase64 = imageBase64.replace(/^data:image\/[a-z]+;base64,/, "");

    const prompt = `You are an expert OCR receipt parser.
Extract information from the receipt accurately and return valid JSON.
Return all text fields (title, merchant_name, notes) as clean single-line strings without raw newline breaks.

Map "category" to exactly one of:
- طعام ومشروبات
- تسوق
- مواصلات
- فواتير وخدمات
- صحة
- أخرى`;

    const requestBody = {
      contents: [
        {
          parts: [
            { text: prompt },
            {
              inline_data: {
                mime_type: "image/jpeg",
                data: cleanedBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        response_mime_type: "application/json",
        response_schema: {
          type: "OBJECT",
          properties: {
            title: { type: "STRING" },
            merchant_name: { type: "STRING" },
            amount: { type: "NUMBER" },
            currency: { type: "STRING" },
            category: { type: "STRING" },
            date: { type: "STRING" },
            notes: { type: "STRING" }
          },
          required: ["title", "merchant_name", "amount", "currency", "category", "date"]
        },
        maxOutputTokens: 2048,
        temperature: 0.1,
      },
    };

    // تسلسل النماذج الاحتياطية لتفادي أي ضغط خوادم
    const models = ["gemini-3.8-flash", "gemini-2.0-flash", "gemini-1.5-flash"];
    let parsedData: any = null;
    let lastError = "";

    for (const model of models) {
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          const response = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "x-goog-api-key": apiKey.trim(),
              },
              body: JSON.stringify(requestBody),
            }
          );

          const data = await response.json();

          if (response.ok && data.candidates?.[0]?.content?.parts?.[0]?.text) {
            let rawText = data.candidates[0].content.parts[0].text.trim();
            rawText = rawText.replace(/^```json\s*/, "").replace(/\s*```$/, "");
            parsedData = JSON.parse(rawText);
            break;
          }

          lastError = data.error?.message || JSON.stringify(data.error) || "Server busy";
          
          const isDemandError = 
            lastError.toLowerCase().includes("high demand") || 
            response.status === 429 || 
            response.status === 503;

          if (!isDemandError) {
            // خطأ آخر ليس له علاقة بالضغط، لا داعي لإعادة المحاولة على نفس النموذج
            break;
          }

          // انتظار تصاعدي قبل المحاولة مجدداً
          await new Promise((r) => setTimeout(r, 1200 * (attempt + 1)));
        } catch (e: any) {
          lastError = e.message;
        }
      }

      if (parsedData) {
        break; // نجحت القراءة
      }
    }

    if (!parsedData) {
      throw new Error(lastError || "فشل تحليل الفاتورة، يرجى المحاولة مجدداً");
    }

    return new Response(JSON.stringify(parsedData), {
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