export const waitForCloseAnimation = async ({ nodes = [], fallbackMs = 220 } = {}) => {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

  const animatedNodes = nodes.filter(Boolean)
  const animations = animatedNodes.flatMap((node) =>
    node.getAnimations().filter((animation) => animation.playState !== "finished")
  )

  if (animations.length > 0) {
    await Promise.all(animations.map((animation) => animation.finished.catch(() => null)))
    return
  }

  await new Promise((resolve) => window.setTimeout(resolve, fallbackMs))
}
