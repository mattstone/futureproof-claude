# Agent eval harness. The invariant evals run in the normal `test` suite (so
# they gate every PR); this task is for running them in isolation, and for
# opting into the live-model tier locally / pre-release.
#
#   bin/rails evals:support                      # invariant evals only
#   RUN_LLM_EVALS=1 bin/rails evals:support      # + live-model evals (needs ANTHROPIC_API_KEY)
namespace :evals do
  desc "Run the customer-support agent eval harness (RUN_LLM_EVALS=1 adds live-model evals)"
  task :support do
    sh "bin/rails test test/evals/customer_support_eval_test.rb"
  end
end
