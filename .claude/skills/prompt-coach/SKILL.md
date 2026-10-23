---
description: Guide the user from a rough idea to a clear prompt, then answer it. Use when the user runs /prompt-coach or asks for help phrasing a request.
---

The user has a rough idea: $ARGUMENTS

Turn it into a clear prompt, then answer it. Follow these steps in order.

1. **Read first, ask later.** If the idea mentions a repo, file, or doc, read the relevant parts (read-only). Do not ask anything you can find out yourself.

2. **Ask only what is missing.** Use the question tool with short multiple-choice options. Skip any item already clear. Cover at most:
   - Goal: what should be true when this is done?
   - Mode: explain, plan only, fix, build, review, or write a doc?
   - Done when: how will we both know it worked?
   - Decided already: any choices not to re-open?
   - Constraints: things to avoid, such as editing files, adding dependencies, or confidential details?
   Keep it to 4 questions or fewer per round. If the user says "skip", move on.

3. **Play it back.** Write the final prompt in one short paragraph: "Here is what I understood: ...". Ask the user to confirm or correct it. Do not start the work until they confirm.

4. **Then answer it**, using these rules:
   - Short answers, simple words, little jargon. Define any term you must use.
   - For code: say what you changed, then why, so the user learns and doesn't just rely on the result.
   - If plan mode is on or the mode is "plan only", make no edits.

Never invent facts about the user's project. If unsure, say so and ask.
