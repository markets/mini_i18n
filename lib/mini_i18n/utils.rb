module MiniI18n
  module Utils
    extend self

    def interpolate(string, keys)
      string % keys
    rescue KeyError
      string
    end

    def deep_merge(merge_to, merge_from)
      merged = merge_to.dup  # dup is faster than clone for simple hashes

      merge_from.each do |key, value|
        string_key = key.to_s

        if value.is_a?(Hash) && merged[string_key].is_a?(Hash)
          merged[string_key] = deep_merge(merged[string_key], value)
        else
          merged[string_key] = value
        end
      end

      merged
    end
  end
end