export async function GET(): Promise<void | Response> {
  return Response.json({ deployedVersion: process.env.VERSION });
}
