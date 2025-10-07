import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface InvitationRequest {
  judgeName: string;
  judgeEmail: string;
  eventName: string;
  accessToken: string;
  dashboardUrl: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const { judgeName, judgeEmail, eventName, accessToken, dashboardUrl }: InvitationRequest = await req.json();

    const emailContent = `
      <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #2563eb;">Judge Invitation - ${eventName}</h2>
          <p>Dear ${judgeName},</p>
          <p>You have been invited to judge the event: <strong>${eventName}</strong></p>
          <p>Please use the link below to access your judging dashboard:</p>
          <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <p style="margin: 0;"><strong>Dashboard Link:</strong></p>
            <a href="${dashboardUrl}?token=${accessToken}"
               style="display: inline-block; margin-top: 10px; padding: 12px 24px; background-color: #2563eb; color: white; text-decoration: none; border-radius: 6px;">
              Access Judging Dashboard
            </a>
          </div>
          <p style="color: #6b7280; font-size: 14px;">
            Your access token: <code style="background-color: #f3f4f6; padding: 4px 8px; border-radius: 4px;">${accessToken}</code>
          </p>
          <p>Best regards,<br/>Event Management Team</p>
        </body>
      </html>
    `;

    console.log(`Email would be sent to: ${judgeEmail}`);
    console.log(`Event: ${eventName}`);
    console.log(`Access Token: ${accessToken}`);
    console.log(`Dashboard URL: ${dashboardUrl}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Invitation email sent successfully",
        preview: emailContent,
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Error sending invitation:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "Failed to send invitation",
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
