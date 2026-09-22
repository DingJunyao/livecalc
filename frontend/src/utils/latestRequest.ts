export function createLatestRequestGuard() {
  let latestRequestId = 0

  return async <T>(request: () => Promise<T>): Promise<T> => {
    const requestId = ++latestRequestId

    try {
      const value = await request()
      if (requestId !== latestRequestId) {
        throw new Error('Superseded by a newer request')
      }
      return value
    } catch (error) {
      if (requestId !== latestRequestId) {
        throw new Error('Superseded by a newer request')
      }
      throw error
    }
  }
}
