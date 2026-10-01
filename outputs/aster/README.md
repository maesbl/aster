# Aster

A private personal AI companion for thinking, creating, and planning.

## Using your companion

- Start a conversation from the message box. Enter sends; Shift+Enter adds a line.
- Choose Think to explore an idea, Create to make something, or Plan to find the next steps.
- Open **Make Aster yours** to change its name and tone or add your preferred name.
- Open **What Aster remembers** to choose, edit, or clear the context sent with each conversation.
- Previous conversations are saved on the device you use. You can reopen or delete them from the sidebar.
- Stop an answer at any time, retry a failed request, or copy an answer.

## Current connection status

The OpenAI connection is configured. A live request reached OpenAI, but the selected project returned `credit_balance_exhausted`. Add API credits in the selected OpenAI organization, then try again. Successful live generation has not yet been verified.

Messages and remembered context are sent to OpenAI to generate responses. The app requests `store: false`. Conversations, profile, and memories are kept in this browser's local storage; they do not sync between devices. The API key stays on the server.

This first version is a text companion. It does not browse the web, generate images, access your files, speak, or perform actions in other apps.

## Development

This project uses React, TypeScript, Vinext, and Cloudflare Workers. Install with `npm run install:ci`, build with `npm run build`, and check types with `node node_modules/typescript/bin/tsc --noEmit`.

The approved local API key is stored in the parent chat workspace's `.env.local`, outside this source directory. To preview locally, load that file through Node's `--env-file` option when running `scripts/run-framework.mjs dev --host 127.0.0.1`. Never include credentials in the source or client code. Production configuration uses the Sites secret `OPENAI_API_KEY` and environment variable `OPENAI_MODEL` (currently `gpt-5.4`).

The root page and chat API require a signed-in user. Production Sites access is owner-only. The starter emulates sign-in for the local preview.

## Verification

- TypeScript type checks and production build.
- Browser inspection of the interface, settings, conversation history, and mobile navigation.
- API rejects unauthenticated, malformed, and cross-site requests.
- The live API connection returns a clear credit message instead of an invented answer.
- Browser agent tools can read conversation state and stage a message without sending it; invalid staging inputs are rejected.
