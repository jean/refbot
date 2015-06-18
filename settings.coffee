for k, v of process.env
    module.exports[k] = v

module.exports.SERVICE_URL   = process.env.SERVICE_URL or 'http://refs.websitesfortrello.com'
