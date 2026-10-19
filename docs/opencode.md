# OpenCode on desktop

The desktop Home Manager configuration installs OpenCode from the separately
locked `nixpkgsOpencode` input. This lets us update the coding agent without
upgrading the rest of the desktop. Update it with
`nix --store daemon flake update nixpkgsOpencode`, then check, build, and switch
the desktop as usual. Let Nix manage updates rather than `opencode upgrade`.

## Connect directly to Z.ai

OpenCode runs locally and connects directly to Z.ai for inference. This setup
does not require an OpenCode Console account or uploading keys to its gateway.
Repository context sent to the model goes to Z.ai.

For pay-as-you-go access:

1. Sign in at [Z.ai](https://z.ai/).
2. Add prepaid credit through [Billing](https://z.ai/manage-apikey/billing).
3. Create a Standard API Key in
   [API Keys](https://z.ai/manage-apikey/apikey-list), named for this desktop.
4. In a terminal, run `opencode auth login`, select **Z.AI**, and paste the key
   into the local prompt.
5. Run `opencode --agent plan --model zai/glm-5.3` in a project directory.

For a GLM Coding Plan subscription, get the key through
[Personal Coding Plan > Plan Overview](https://z.ai/manage-apikey/apikey-list),
choose **Z.AI Coding Plan** during login, and launch with
`opencode --agent plan --model zai-coding-plan/glm-5.3` instead.

The two providers use different endpoints:

| Provider | Base URL |
| --- | --- |
| Z.AI | `https://api.z.ai/api/paas/v4` |
| Z.AI Coding Plan | `https://api.z.ai/api/coding/paas/v4` |

Inside OpenCode, `/models` changes the model. Start with a prompt such as
"Explain this repository and suggest one small improvement. Do not edit files."
Switch from Plan to Build when ready to make changes.

Enter credentials only into the local authentication prompt. Keep them out of
Nix files, the Nix store, Git, shell command arguments, and chat messages.
Model access and a real inference request still need verification after login.

Sources: [OpenCode provider setup](https://opencode.ai/docs/providers/#zai),
[Z.ai OpenCode guide](https://docs.z.ai/devpack/tool/opencode),
[Z.ai API quick start](https://docs.z.ai/guides/overview/quick-start), and
[GLM-5.3](https://docs.z.ai/guides/llm/glm-5.3).
