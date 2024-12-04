# frozen_string_literal: true

require 'spec_helper'
require 'rake'

RSpec.describe "simplecov.rake" do
  before(:all) do
    Rake.application.rake_require("tasks/simplecov")
  end

  describe "simplecov:collate_results" do
    context "when there are reports to merge" do
      let(:input_dir) { Rails.root.join("spec/fixtures/simplecov") }

      it "creates a new combined report" do
        Dir.mktmpdir do |tmp_dir|
          output_dir = File.join(tmp_dir, "output")

          expect {
            Rake.application.invoke_task(
              "simplecov:collate_results[#{input_dir},#{output_dir}]"
            )
          }.to change { Dir.exist?(output_dir) }.
            from(false).
            to(true).

            and change { File.exist?(File.join(output_dir, "index.html")) }.
            from(false).
            to(true)
        end
      end
    end
  end
end
