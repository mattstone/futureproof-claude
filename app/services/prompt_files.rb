# PromptFiles — read-only access to the prompt files in docs/prompts/.
#
# The repo (and therefore the deployed container) is the single source of
# truth for all prompts. This loader is how the app and the admin UI read
# "what is". Changes happen only via pull requests (see Admin::PromptsController
# and GithubBridge) — nothing app-side ever writes these files.
class PromptFiles
  Slot = Struct.new(:layer, :key, :name, :path, :description, keyword_init: true)

  ROOT = "docs/prompts".freeze

  # All known prompt slots. The registry is the single map between
  # (layer, key) and the file path, shared by the runtime loader, the admin
  # browser, and the PR bridge.
  SLOT_REGISTRY = [
    Slot.new(layer: :core, key: "master", name: "Master (core rules)",
             path: "#{ROOT}/master.md",
             description: "Shared core: identity, advice wall, tenant isolation, terminology, output/safety rules. Non-negotiables live ONLY here."),

    Slot.new(layer: :agent, key: "akane", name: "Akane — acquisition & onboarding",
             path: "#{ROOT}/agents/akane.md", description: "Role layer for the acquisition/onboarding agent."),
    Slot.new(layer: :agent, key: "misato", name: "Misato — customer service",
             path: "#{ROOT}/agents/misato.md", description: "Role layer for the customer comms/service agent."),
    Slot.new(layer: :agent, key: "rie", name: "Rie — back office",
             path: "#{ROOT}/agents/rie.md", description: "Role layer for the back-office agent."),
    Slot.new(layer: :agent, key: "yumi", name: "Yumi — investment manager",
             path: "#{ROOT}/agents/yumi.md", description: "Role layer for the investment-account agent."),
    Slot.new(layer: :agent, key: "motoko", name: "Motoko — engineering & ops",
             path: "#{ROOT}/agents/motoko.md", description: "Role layer for the master engineering/ops agent."),

    Slot.new(layer: :constituent, key: "customers", name: "Customers (audience)",
             path: "#{ROOT}/constituents/customers.md", description: "Audience layer: plain language, no debt language."),
    Slot.new(layer: :constituent, key: "brokers", name: "Brokers (audience)",
             path: "#{ROOT}/constituents/brokers.md", description: "Audience layer: professional, channel-specific."),
    Slot.new(layer: :constituent, key: "lenders", name: "Lenders (audience)",
             path: "#{ROOT}/constituents/lenders.md", description: "Audience layer: operational, staff-oriented."),
    Slot.new(layer: :constituent, key: "investments", name: "Investments (audience)",
             path: "#{ROOT}/constituents/investments.md", description: "Audience layer: investment domain."),
    Slot.new(layer: :constituent, key: "wholesale_funders", name: "Wholesale funders (audience)",
             path: "#{ROOT}/constituents/wholesale-funders.md", description: "Audience layer: precise, reporting-oriented."),

    Slot.new(layer: :runtime, key: "support_chat", name: "Support chat — persona & guardrails",
             path: "#{ROOT}/runtime/support_chat.md",
             description: "LIVE system prompt for the customer support chat (persona + hard guardrails). " \
                          "The knowledge-base section is generated from code (CustomerSupportService::KNOWLEDGE_BASE), not from this file."),
    Slot.new(layer: :runtime, key: "support_chat_region_au", name: "Support chat — AU region context",
             path: "#{ROOT}/runtime/support_chat_regions/au.md", description: "LIVE region addendum appended for Australian users."),
    Slot.new(layer: :runtime, key: "support_chat_region_us", name: "Support chat — US region context",
             path: "#{ROOT}/runtime/support_chat_regions/us.md", description: "LIVE region addendum appended for US users."),
    Slot.new(layer: :runtime, key: "support_chat_region_nz", name: "Support chat — NZ region context",
             path: "#{ROOT}/runtime/support_chat_regions/nz.md", description: "LIVE region addendum appended for NZ users."),
    Slot.new(layer: :runtime, key: "support_chat_region_uk", name: "Support chat — UK region context",
             path: "#{ROOT}/runtime/support_chat_regions/uk.md", description: "LIVE region addendum appended for UK users."),
    Slot.new(layer: :runtime, key: "support_chat_region_default", name: "Support chat — default region context",
             path: "#{ROOT}/runtime/support_chat_regions/default.md", description: "LIVE region addendum when the user's region is unknown.")
  ].freeze

  LAYERS = SLOT_REGISTRY.map(&:layer).uniq.freeze

  class << self
    # Overridable for tests (point at an empty dir to exercise fallbacks).
    attr_writer :root

    def root
      @root ||= Rails.root
    end

    def all_slots
      SLOT_REGISTRY
    end

    def slots_for(layer)
      SLOT_REGISTRY.select { |s| s.layer == layer.to_sym }
    end

    def slot(layer, key)
      SLOT_REGISTRY.find { |s| s.layer == layer.to_sym && s.key == key.to_s }
    end

    def find_by_key(key)
      SLOT_REGISTRY.find { |s| s.key == key.to_s }
    end

    # Raw file content, or nil if the file is absent. Memoized outside
    # development (content only changes via deploy).
    def read(layer, key)
      s = slot(layer, key) or return nil
      content = if Rails.env.development?
        read_file(s.path)
      else
        cache[s.path] ||= read_file(s.path)
      end
      content == :missing ? nil : content
    end

    # Short content fingerprint used in per-call prompt references
    # (AI_BUILD_SPEC §9) and in the admin display.
    def sha(layer, key)
      content = read(layer, key)
      content && Digest::SHA256.hexdigest(content)[0, 12]
    end

    def reset_cache!
      @cache = nil
      @root = nil
    end

    private

    def cache
      @cache ||= {}
    end

    def read_file(relative_path)
      full = File.join(root, relative_path)
      return :missing unless File.exist?(full)

      File.read(full).freeze
    end
  end
end
