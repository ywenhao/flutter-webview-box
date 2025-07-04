const _cbMap = new Map()

let _cbId = 0

const _registerCallback = <T>(resolve: (value: T) => void, reject: (reason?: any) => void) => {
  const id = `jsCallback${_cbId++}`
  _cbMap.set(id, { resolve, reject })
  if (!(window as any).jsResolve) {
    ;(window as any).jsResolve = (id: string, value: any) => {
      const cb = _cbMap.get(id)
      if (cb) {
        _cbMap.delete(id)
        cb.resolve(value)
      }
    }
    ;(window as any).jsReject = (id: string, reason?: any) => {
      const cb = _cbMap.get(id)
      if (cb) {
        _cbMap.delete(id)
        try {
          if (reason) {
            cb.reject(reason)
          } else {
            cb.reject({})
          }
          // eslint-disable-next-line no-unused-vars
        } catch (err) {
          cb.reject(reason || err)
        }
      }
    }
  }
  return id
}

const postMessageToNative = (method: string, args?: any, cbId?: string) => {
  if (isReady()) {
    let params: any = { method, args }
    if (typeof cbId !== 'undefined' && cbId !== null) {
      params = { ...params, _cbId: cbId }
    }
    // @ts-ignore
    window.FlutterBridge.postMessage(JSON.stringify(params))
  }
}

const _invoke = (method: string, args?: any) => postMessageToNative(method, args)

const _invokeWithResult = <T>(method: string, args?: any): Promise<T> => {
  return new Promise<T>((resolve, reject) => {
    if (isReady()) {
      const id = _registerCallback(resolve, reject)
      postMessageToNative(method, args, id)
    } else {
      reject('jsBridge is not ready')
    }
  })
}

const isReady = () => !!(window as any).FlutterBridge

export const flutterBridge = {
  test: () => _invoke('test'),
  testResult: () => _invokeWithResult<string>('testResult'),
}
