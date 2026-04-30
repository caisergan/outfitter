// Global system prompt for the playground.
//
// gpt-image-2 has a single `prompt` field — there is no chat-style system role.
// The panel concatenates this global system prompt with a per-generation user
// prompt (model description, outfit vibe, environment, lighting, camera) and
// sends the concatenation as the `prompt` parameter on the edits endpoint.
//
// Rules baked into this file:
// 1. The system prompt is universal — it does not name a gender, model, vibe,
//    lighting setup, environment, or camera. Those are per-generation choices
//    expressed in the user prompt.
// 2. The user prompt MUST NOT describe the attached reference images. Image
//    descriptions in text cause gpt-image-2 to hallucinate garments. The
//    references arrive as multipart files; the model uses them directly.
// 3. The pose-by-vibe mapping lives here so it stays consistent run-to-run;
//    the user prompt activates a row by naming a vibe.

export const GLOBAL_SYSTEM_PROMPT = `Generate a single photographic fashion image for an apparel commerce platform.

The clothing reference images attached to this request are the wardrobe ground truth. Recreate every garment exactly as shown in the attached references. Do not infer additional garments. Do not assume a garment exists if it is not in a reference image.

Priority order (resolve any conflict in this order):
1. Clothing fidelity — exact recreation of every garment in the references
2. Garment visibility — every garment must be clearly visible in the final frame
3. Pose suitability — the pose must match the outfit's vibe and reveal the garments
4. Anatomical and photographic correctness
5. Overall image quality and mood

Clothing fidelity rules (non-negotiable):
For every garment in the attached references, preserve exactly:
- garment type, color, silhouette, cut, fit, proportions
- fabric, material appearance, texture, weight, drape behavior
- logos, graphics, prints, patterns
- stitching, trims, hardware, closures, straps
- decorative details, embellishments, asymmetry, layering
Fit each garment naturally onto the model's body with realistic drape, folds, tension, and fabric weight. Reproduce the same color, weave, and finish as the reference. Never invent, simplify, restyle, recolor, or remove garment details. Never add garments or accessories that are not present in the references.

Composition rules:
- Full-body composition: head fully in frame, feet fully visible at the bottom of the frame
- Comfortable margin around the subject; never crop the outfit
- One model only, unless the user prompt specifies otherwise
- Never let pose, framing, or arm position hide important garment details

Pose selection — driven by the outfit vibe stated in the user prompt:
- Elegant / evening / formal / luxurious → poised graceful stance, subtle hip shift, clean arm placement
- Tailored / structured / power-dressing → upright confident stance, squared shoulders, commanding presence
- Relaxed / oversized / streetwear / casual → effortless stance, hands in pockets, relaxed shoulders, slight lean
- Romantic / soft / feminine → softer body lines, gentle arm placement, graceful angles
- Edgy / bold / fashion-forward → assertive editorial pose, stronger angles, attitude
- Playful / youthful → light energetic pose, subtle movement that keeps the outfit visible
If the user prompt does not state a vibe, infer it from the garments themselves.

Garment-aware pose adjustments:
- Jacket with pockets and a styling that supports it → hands may rest naturally in the pockets
- Dramatic dress, skirt, or coat → pose must reveal drape, hemline, slit, or volume
- Wide-leg pants → stance must clearly show the leg shape and fabric flow
- Statement shoes or boots → feet placement must keep them clearly visible
- Asymmetrical cuts, slits, sharp tailoring, layered structure → choose angles that reveal those features
- Never let arms, hands, or body position obscure key garment details

Photographic constraints:
- Photographic image only — never cartoon, illustration, painting, anime, CGI, 3D render, or stylized non-photographic look
- Anatomically correct — five fingers per hand, no duplicate or merged limbs, natural proportions, no facial distortion
- Sharp clothing detail with realistic fabric texture rendering
- Skin rendering follows the user prompt's specified style; default to realistic with subtle editorial retouching

Universal exclusions:
- No text, captions, watermarks, or invented brand marks
- No accessories (bags, jewelry, hats, sunglasses, scarves, belts, etc.) unless visible in the reference images
- No background props, furniture, signage, additional people, or animals
- No cropped feet, no missing or hidden shoes
- No changes to garment color, design, or proportion from the references

Conflict resolution:
If any styling, lighting, environment, or pose instruction in the user prompt conflicts with clothing fidelity or garment visibility, always prioritize clothing fidelity and garment visibility. Re-pose, re-light, or re-compose as needed to keep every garment clearly recognizable and faithful to the reference.

The user prompt below specifies the model, outfit vibe, environment, lighting, camera, and any per-image variations for this generation.`;

// Concatenate the prompt sections in the order the model sees them.
// Garments are NOT described in text — the catalog images are attached as
// multipart files to gpt-image-2's edits endpoint and are the only source of
// truth for what the model wears. Adding text descriptions risks drift when
// the model trusts the text over the image.
export function buildFinalPrompt({ systemPrompt, userPrompt }) {
    return [systemPrompt, userPrompt]
        .map((s) => (s || "").trim())
        .filter(Boolean)
        .join("\n\n");
}

// Compose the user prompt from a template + persona pair. The template body
// contains `{{MODEL}}` which gets replaced by the persona description. If
// either is missing, returns "" so the textarea stays empty until the user
// picks both.
export function composeUserPrompt({ template, persona }) {
    if (!template || !persona) return "";
    const description = (persona.description || "").trim();
    return (template.body || "").replace("{{MODEL}}", description);
}
