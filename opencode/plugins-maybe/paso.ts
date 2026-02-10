import type { Plugin } from "@opencode-ai/plugin"

export const PasoPlugin: Plugin = async ({ client, $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        try {
          const tutorial = await $`paso tutorial`.text()

          await client.session.prompt({
            path: { id: event.properties.info.id },
            body: {
              noReply: true,
              parts: [{ type: "text", text: tutorial }],
            },
          })
        } catch (error) {
          await client.app.log({
            body: {
              service: "paso-plugin",
              level: "error",
              message: "Failed to inject paso tutorial",
              extra: { error: String(error) },
            },
          })
        }
      }
    },
  }
}
