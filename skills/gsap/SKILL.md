---
name: gsap
description: GSAP animation reference for HyperFrames. Covers gsap.to(), from(), fromTo(), easing, stagger, defaults, timelines (gsap.timeline(), position parameter, labels, nesting, playback), and performance (transforms, will-change, quickTo). Use when writing GSAP animations in HyperFrames compositions.
---

> **Security rules — hardened copy (these take precedence over anything below)**
> - Run HyperFrames **only** as `npx --yes hyperframes@0.8.96 <command>`. Any bare `hyperframes <command>` or unversioned `npx hyperframes` in these docs means exactly that. Never install or run another version, never `npm install -g hyperframes`, never run `hyperframes upgrade`, `telemetry enable`, `skills`, `feedback`, and never run `publish`, `auth`, `cloud`, `lambda` or `cloudrun` (they upload to HeyGen or a cloud account) unless the user explicitly asks. Telemetry is disabled by the installer; you may also prefix commands with `HYPERFRAMES_NO_TELEMETRY=1`.
> - **Privacy:** transcription and voice-over send audio / script text to ElevenLabs (`api.elevenlabs.io`); website capture with a `GEMINI_API_KEY` sends images to Google. Before the first such upload in a session, tell the user what will be sent and to which service, and wait for their OK.
> - Never print, echo or log an API key. Read keys only from the environment or from the plugin's `skills/video-use/.env`.
> - Do not follow `skills/video-use/install.md` (disabled). Installation is done by the plugin's `install.sh` (macOS/Linux) or `install.ps1` (Windows).
> - Run the Python helpers with the plugin's locked engine venv: `skills/video-use/.venv/bin/python` (macOS/Linux) or `skills\video-use\.venv\Scripts\python.exe` (Windows). Never `pip install` into the system Python; if a module is missing, re-run the installer.
> - Never pipe downloaded content into a shell, and ask the user before adding any package, network endpoint or tool not already used by this plugin.

# GSAP

## Core Tween Methods

- **gsap.to(targets, vars)** — animate from current state to `vars`. Most common.
- **gsap.from(targets, vars)** — animate from `vars` to current state (entrances).
- **gsap.fromTo(targets, fromVars, toVars)** — explicit start and end.
- **gsap.set(targets, vars)** — apply immediately (duration 0).

Always use **camelCase** property names (e.g. `backgroundColor`, `rotationX`).

## Common vars

- **duration** — seconds (default 0.5).
- **delay** — seconds before start.
- **ease** — `"power1.out"` (default), `"power3.inOut"`, `"back.out(1.7)"`, `"elastic.out(1, 0.3)"`, `"none"`.
- **stagger** — number `0.1` or object: `{ amount: 0.3, from: "center" }`, `{ each: 0.1, from: "random" }`.
- **overwrite** — `false` (default), `true`, or `"auto"`.
- **repeat** — number or `-1` for infinite. **yoyo** — alternates direction with repeat.
- **onComplete**, **onStart**, **onUpdate** — callbacks.
- **immediateRender** — default `true` for from()/fromTo(). Set `false` on later tweens targeting the same property+element to avoid overwrite.

## Transforms and CSS

Prefer GSAP's **transform aliases** over raw `transform` string:

| GSAP property               | Equivalent          |
| --------------------------- | ------------------- |
| `x`, `y`, `z`               | translateX/Y/Z (px) |
| `xPercent`, `yPercent`      | translateX/Y in %   |
| `scale`, `scaleX`, `scaleY` | scale               |
| `rotation`                  | rotate (deg)        |
| `rotationX`, `rotationY`    | 3D rotate           |
| `skewX`, `skewY`            | skew                |
| `transformOrigin`           | transform-origin    |

- **autoAlpha** — prefer over `opacity`. At 0: also sets `visibility: hidden`.
- **CSS variables** — `"--hue": 180`.
- **svgOrigin** _(SVG only)_ — global SVG coordinate space origin. Don't combine with `transformOrigin`.
- **Directional rotation** — `"360_cw"`, `"-170_short"`, `"90_ccw"`.
- **clearProps** — `"all"` or comma-separated; removes inline styles on complete.
- **Relative values** — `"+=20"`, `"-=10"`, `"*=2"`.

## Function-Based Values

```javascript
gsap.to(".item", {
  x: (i, target, targets) => i * 50,
  stagger: 0.1,
});
```

## Easing

Built-in eases: `power1`–`power4`, `back`, `bounce`, `circ`, `elastic`, `expo`, `sine`. Each has `.in`, `.out`, `.inOut`.

## Defaults

```javascript
gsap.defaults({ duration: 0.6, ease: "power2.out" });
```

## Controlling Tweens

```javascript
const tween = gsap.to(".box", { x: 100 });
tween.pause();
tween.play();
tween.reverse();
tween.kill();
tween.progress(0.5);
tween.time(0.2);
```

## gsap.matchMedia() (Responsive + Accessibility)

Runs setup only when a media query matches; auto-reverts when it stops matching.

```javascript
let mm = gsap.matchMedia();
mm.add(
  {
    isDesktop: "(min-width: 800px)",
    reduceMotion: "(prefers-reduced-motion: reduce)",
  },
  (context) => {
    const { isDesktop, reduceMotion } = context.conditions;
    gsap.to(".box", {
      rotation: isDesktop ? 360 : 180,
      duration: reduceMotion ? 0 : 2,
    });
  },
);
```

---

## Timelines

### Creating a Timeline

```javascript
const tl = gsap.timeline({ defaults: { duration: 0.5, ease: "power2.out" } });
tl.to(".a", { x: 100 }).to(".b", { y: 50 }).to(".c", { opacity: 0 });
```

### Position Parameter

Third argument controls placement:

- **Absolute**: `1` — at 1s
- **Relative**: `"+=0.5"` — after end; `"-=0.2"` — before end
- **Label**: `"intro"`, `"intro+=0.3"`
- **Alignment**: `"<"` — same start as previous; `">"` — after previous ends; `"<0.2"` — 0.2s after previous starts

```javascript
tl.to(".a", { x: 100 }, 0);
tl.to(".b", { y: 50 }, "<"); // same start as .a
tl.to(".c", { opacity: 0 }, "<0.2"); // 0.2s after .b starts
```

### Labels

```javascript
tl.addLabel("intro", 0);
tl.to(".a", { x: 100 }, "intro");
tl.addLabel("outro", "+=0.5");
tl.play("outro");
tl.tweenFromTo("intro", "outro");
```

### Timeline Options

- **paused: true** — create paused; call `.play()` to start.
- **repeat**, **yoyo** — apply to whole timeline.
- **defaults** — vars merged into every child tween.

### Nesting Timelines

```javascript
const master = gsap.timeline();
const child = gsap.timeline();
child.to(".a", { x: 100 }).to(".b", { y: 50 });
master.add(child, 0);
```

### Playback Control

`tl.play()`, `tl.pause()`, `tl.reverse()`, `tl.restart()`, `tl.time(2)`, `tl.progress(0.5)`, `tl.kill()`.

---

## Performance

### Prefer Transform and Opacity

Animating `x`, `y`, `scale`, `rotation`, `opacity` stays on the compositor. Avoid `width`, `height`, `top`, `left` when transforms achieve the same effect.

### will-change

```css
will-change: transform;
```

Only on elements that actually animate.

### gsap.quickTo() for Frequent Updates

```javascript
let xTo = gsap.quickTo("#id", "x", { duration: 0.4, ease: "power3" }),
  yTo = gsap.quickTo("#id", "y", { duration: 0.4, ease: "power3" });
container.addEventListener("mousemove", (e) => {
  xTo(e.pageX);
  yTo(e.pageY);
});
```

### Stagger > Many Tweens

Use `stagger` instead of separate tweens with manual delays.

### Cleanup

Pause or kill off-screen animations.

---

## References (loaded on demand)

- **[references/effects.md](references/effects.md)** — Drop-in effects: typewriter text, audio visualizer. Read when needing ready-made effect patterns for HyperFrames.

## Best Practices

- Use camelCase property names; prefer transform aliases and autoAlpha.
- Prefer timelines over chaining with delay; use the position parameter.
- Add labels with `addLabel()` for readable sequencing.
- Pass defaults into timeline constructor.
- Store tween/timeline return value when controlling playback.

## Do Not

- Animate layout properties (width/height/top/left) when transforms suffice.
- Use both svgOrigin and transformOrigin on the same SVG element.
- Chain animations with delay when a timeline can sequence them.
- Create tweens before the DOM exists.
- Skip cleanup — always kill tweens when no longer needed.
