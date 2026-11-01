# frozen_string_literal: true

class PurlLookupResolver
  def initialize(purl)
    @purl = purl
  end

  def ecosystem
    case @purl.type
    when "apk"
      @purl.namespace if %w[alpine postmarketos].include?(@purl.namespace)
    when "deb"
      @purl.namespace if %w[debian ubuntu].include?(@purl.namespace)
    else
      Ecosystem::Base.purl_type_to_ecosystem(@purl.type)
    end
  end

  def package_name(namespace: @purl.namespace)
    return @purl.name if %w[apk deb].include?(@purl.type)

    separator = Ecosystem::Base.purl_type_to_namespace_separator(@purl.type)
    return if separator.nil?

    [namespace, @purl.name].compact.join(separator)
  end

  def registry_ids
    return [] if ecosystem.blank?

    registries = Registry.where(ecosystem: ecosystem)
    qualifiers = @purl.qualifiers || {}
    repository_url = qualifiers["repository_url"]
    distro = qualifiers["distro"]
    return registries.pluck(:id) if repository_url.blank? && distro.blank?

    target_url = normalize_url(repository_url)
    registries.filter_map do |registry|
      next if repository_url.present? && normalize_url(registry.url) != target_url
      next if distro.present? && !matches_distro?(registry, distro)

      registry.id
    end
  end

  private

  def matches_distro?(registry, distro)
    return false if registry.version.blank?

    ecosystem = registry.ecosystem_instance
    ecosystem.respond_to?(:distro_qualifier) && ecosystem.distro_qualifier == distro
  rescue NotImplementedError
    false
  end

  def normalize_url(url)
    url.to_s.downcase.sub(%r{/+$}, "")
  end
end
