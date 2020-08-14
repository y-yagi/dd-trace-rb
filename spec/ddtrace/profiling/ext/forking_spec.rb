require 'spec_helper'
require 'ddtrace/profiling'
require 'ddtrace/profiling/ext/forking'

RSpec.describe Datadog::Profiling::Ext::Forking do
  describe '::apply!' do
    subject(:apply!) { described_class.apply! }

    let(:toplevel_receiver) do
      if TOPLEVEL_BINDING.respond_to?(:receiver)
        TOPLEVEL_BINDING.receiver
      else
        TOPLEVEL_BINDING.eval('self')
      end
    end

    let(:toplevel_class) { Class.new }

    around do |example|
      unmodified_process_class = ::Process.dup
      unmodified_kernel_class = ::Kernel.dup

      example.run

      Object.send(:remove_const, :Process)
      Object.const_set('Process', unmodified_process_class)

      Object.send(:remove_const, :Kernel)
      Object.const_set('Kernel', unmodified_kernel_class)
    end

    before do
      # NOTE: There's no way to undo a modification of the TOPLEVEL_BINDING.
      #       The results of this will carry over into other tests...
      #       Just assert that the receiver was patched instead.
      #       Unfortunately means we can't test if "fork" works in main Object.
      allow(toplevel_receiver)
        .to receive(:singleton_class)
        .and_return(toplevel_class)
    end

    after do
      # Check for leaks (make sure test is properly cleaned up)
      expect(::Process.ancestors.include?(described_class::Kernel)).to be false
      expect(::Kernel.ancestors.include?(described_class::Kernel)).to be false
      expect(toplevel_receiver.class.ancestors.include?(described_class::Kernel)).to be false
    end

    it 'applies the Kernel patch' do
      expect(::Process.ancestors).to_not include(described_class::Kernel)
      expect(::Kernel.ancestors).to_not include(described_class::Kernel)
      expect(toplevel_class).to_not include(described_class::Kernel)

      apply!

      expect(::Process.ancestors).to include(described_class::Kernel)
      expect(::Kernel.ancestors).to include(described_class::Kernel)
      expect(toplevel_class).to include(described_class::Kernel)
    end
  end
end

RSpec.describe Datadog::Profiling::Ext::Forking::Kernel do
  context 'when applied to a class with forking' do
    # TODO
  end
end
