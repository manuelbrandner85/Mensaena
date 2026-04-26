/**
 * Generic promise-queue rate limiter.
 *
 * Creates a singleton-chain that ensures at most `requestsPerSecond` requests
 * start per second, preserving FIFO order. Safe to call concurrently from
 * multiple places – all calls share the same queue tail.
 */

export interface RateLimiter {
  /** Enqueue a task; resolves with the task's return value. */
  enqueue<T>(fn: () => Promise<T>): Promise<T>
}

export function createRateLimiter(requestsPerSecond: number): RateLimiter {
  const minIntervalMs = Math.ceil(1_000 / requestsPerSecond)
  let queueTail: Promise<unknown> = Promise.resolve()
  let lastRequestAt = 0

  function enqueue<T>(fn: () => Promise<T>): Promise<T> {
    const result = queueTail.then(async () => {
      const wait = minIntervalMs - (Date.now() - lastRequestAt)
      if (wait > 0) await new Promise(r => setTimeout(r, wait))
      lastRequestAt = Date.now()
      return fn()
    })
    // Don't let errors stop the chain
    queueTail = result.catch(() => undefined)
    return result
  }

  return { enqueue }
}
