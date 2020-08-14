module Datadog
  module Profiling
    module Ext
      # Extensions for forking.
      module Forking
        def self.apply!
          modules = [::Process, ::Kernel]
          # TODO: Remove "else #eval" clause when Ruby < 2.3 support is dropped.
          modules << (TOPLEVEL_BINDING.respond_to?(:receiver) ? TOPLEVEL_BINDING.receiver : TOPLEVEL_BINDING.eval('self'))

          # Patch top-level binding, Kernel, Process
          modules.each do |mod|
            mod.singleton_class.class_eval do
              prepend Kernel
            end
          end
        end

        # Extensions for kernel
        module Kernel
          FORK_STAGES = [:prepare, :parent, :child].freeze

          def fork
            @at_fork_blocks = {} unless instance_variable_defined?(:@at_fork_blocks)

            wrapped_block = proc do
              # Trigger :child callback
              @at_fork_blocks[:child].each(&:call) if @at_fork_blocks.key?(:child)
              yield
            end

            # Trigger :prepare callback
            @at_fork_blocks[:prepare].each(&:call) if @at_fork_blocks.key?(:prepare)

            # Start fork
            result = super(&wrapped_block)

            # Trigger :parent callback and return
            @at_fork_blocks[:parent].each(&:call) if @at_fork_blocks.key?(:parent)
            result
          end

          def at_fork(stage = :prepare, &block)
            raise ArgumentError, 'Bad \'stage\' for ::at_fork' unless FORK_STAGES.include?(stage)

            @at_fork_blocks = {} unless instance_variable_defined?(:@at_fork_blocks)
            @at_fork_blocks[stage] = [] unless @at_fork_blocks.key?(stage)
            @at_fork_blocks[stage] << block
          end
        end
      end
    end
  end
end
