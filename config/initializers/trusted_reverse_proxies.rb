require Rails.root.join("lib/links/trusted_reverse_proxies")

Links::TrustedReverseProxies.apply! if Links::TrustedReverseProxies.configured?
