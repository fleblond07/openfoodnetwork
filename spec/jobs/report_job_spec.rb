# frozen_string_literal: true

require 'spec_helper'

describe ReportJob do
  include CableReady::Broadcaster

  let(:report_args) {
    { report_class:, user:, params:, format:, filename: }
  }
  let(:report_class) { Reporting::Reports::UsersAndEnterprises::Base }
  let(:user) { enterprise.owner }
  let(:enterprise) { create(:enterprise) }
  let(:params) { {} }
  let(:format) { :csv }
  let(:filename) { "report.csv" }

  it "generates a report" do
    job = perform_enqueued_jobs(only: ReportJob) do
      ReportJob.perform_later(**report_args)
    end
    expect_csv_report
  end

  it "enqueues a job for async processing" do
    expect {
      ReportJob.perform_later(**report_args)
    }.to_not change { ActiveStorage::Blob.count }

    expect {
      perform_enqueued_jobs(only: ReportJob)
    }.to change { ActiveStorage::Blob.count }

    expect_csv_report
  end

  it "notifies Cable Ready when the report is done" do
    channel = ScopedChannel.for_id("123")
    with_channel = report_args.merge(channel:)

    ReportJob.perform_later(**with_channel)

    expect(cable_ready[channel]).to receive(:broadcast).and_call_original

    expect {
      perform_enqueued_jobs(only: ReportJob)
    }.to change { ActiveStorage::Blob.count }
  end

  it "triggers an email when the report is done" do
    # Setup test data which also triggers emails:
    report_args

    # Send emails for quick jobs as well:
    stub_const("ReportJob::NOTIFICATION_TIME", 0)

    expect {
      # We need to create this job within the block because of a bug in
      # rspec-rails: https://github.com/rspec/rspec-rails/issues/2668
      ReportJob.perform_later(**report_args)
      perform_enqueued_jobs(only: ReportJob)
    }.to enqueue_mail(ReportMailer, :report_ready).with(
      params: hash_including(
        to: user.email,
      ),
      args: [],
    )
  end

  it "triggers no email when the report is done quickly" do
    # Setup test data which also triggers emails:
    report_args

    expect {
      # We need to create this job within the block because of a bug in
      # rspec-rails: https://github.com/rspec/rspec-rails/issues/2668
      ReportJob.perform_later(**report_args)
      perform_enqueued_jobs(only: ReportJob)
    }.to_not enqueue_mail
  end

  it "rescues errors" do
    expect(report_class).to receive(:new).and_raise
    expect(Bugsnag).to receive(:notify)

    job = ReportJob.perform_later(**report_args)

    expect {
      perform_enqueued_jobs(only: ReportJob)
    }.to_not raise_error
  end

  def expect_csv_report
    blob = ReportBlob.last
    expect(blob.filename.to_s).to eq "report.csv"
    expect(blob.content_type).to eq "text/csv"

    table = CSV.parse(blob.result)
    expect(table[0][1]).to eq "Relationship"
    expect(table[1][1]).to eq "owns"
  end
end
