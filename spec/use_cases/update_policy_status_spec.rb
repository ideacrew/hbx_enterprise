require 'rails_helper'
describe UpdatePolicyStatus do
  subject { UpdatePolicyStatus.new(policy_repo) }

  let(:policy_repo) { double(find_by_id: policy) }
  let(:policy) { Policy.new(aasm_state: current_status, plan: plan, enrollees: enrollees) }
  let(:subscriber) { Enrollee.new(m_id: subscriber_id, relationship_status_code: 'self', coverage_status: subscriber_coverage_status, coverage_start: Date.today.prev_month ) }
  let(:subscriber_id) { '4321'}
  let(:person) { double(:is_authority_member? => true) }

  let(:subscriber_coverage_status) { 'active' }
  let(:subscriber_coverage_start) { Date.today.prev_month }
  let(:subscriber_coverage_end) { nil }


  let(:plan) { Plan.new(hios_plan_id: hios_plan_id) }
  let(:hios_plan_id) { '123456789-01'}

  let(:enrollees) { [subscriber] }
  let(:current_status) { 'effectuated' }
  let(:allowed_statuses) { ['effectuated', 'carrier_canceled', 'carrier_terminated', 'submitted'] }

  let(:listener) { double(policy_not_found: nil, invalid_dates: nil, policy_status_is_same: nil, fail: nil, success: nil, enrollee_end_date_is_different: nil) }

  let(:request) do
    {
      policy_id: '1234',
      status: requested_status,
      begin_date: requested_begin_date,
      end_date: requested_end_date,
      subscriber_id: requested_subscriber_id,
      enrolled_count: requested_enrollee_count,
      hios_plan_id: requested_hios_plan_id
    }
  end

  let(:requested_status) { 'carrier_terminated' }
  let(:requested_begin_date) { Date.today.prev_month }
  let(:requested_end_date) { Date.today }
  let(:requested_subscriber_id) { subscriber_id }
  let(:requested_enrollee_count) { enrollees.length }
  let(:requested_hios_plan_id) { hios_plan_id }

  before :each do
    allow(subscriber).to receive(:person).and_return(person)
  end


  it 'finds the policy' do
    expect(policy_repo).to receive(:find_by_id).with(request[:policy_id])
    expect(listener).not_to receive(:policy_not_found).with(request[:policy_id])
    subject.execute(request, listener)
  end

  it 'changes the policy status' do
    subject.execute(request, listener)
    expect(policy.aasm_state).to eq request[:status]
  end

  it 'saves the policy' do
    expect(policy).to receive(:save)
    subject.execute(request, listener)
  end

  it 'notifies listener of success' do
    expect(listener).to receive(:success)
    subject.execute(request, listener)
  end

  context 'requested status is same as current' do
    let(:requested_status) { current_status }

    it 'notifies the listener' do
      expect(listener).to receive(:policy_status_is_same)
      subject.execute(request, listener)
    end
  end

  context 'policy is not found' do
    let(:policy) { nil }
    it 'notifies a listener' do
      expect(listener).to receive(:policy_not_found).with(request[:policy_id])
      expect(listener).to receive(:fail)

      subject.execute(request, listener)
    end
  end

  context 'when requested subscriber id doesnt match' do
    let(:subscriber_id) { '1234'}
    let(:requested_subscriber_id) { '9999'}
    it 'notifies listener' do
      expect(listener).to receive(:subscriber_id_mismatch).with({provided: requested_subscriber_id, existing: subscriber_id})
      expect(listener).to receive(:fail)
      subject.execute(request, listener)
    end
  end

  context 'when enrollee count does not match' do
    let(:enrollee_count) { enrollees.length}
    let(:requested_enrollee_count) { '99' }
    it 'notifies listener' do
      expect(listener).to receive(:enrolled_count_mismatch).with({provided: requested_enrollee_count, existing: enrollee_count})
      expect(listener).to receive(:fail)

      subject.execute(request, listener)
    end
  end

  context 'when plan does not match' do
    let(:hios_plan_id) { '123456789-01' }
    let(:requested_hios_plan_id) { '987654321-01' }

    it 'notifies listener' do
      expect(listener).to receive(:plan_mismatch).with({provided: requested_hios_plan_id, existing: hios_plan_id})
      expect(listener).to receive(:fail)

      subject.execute(request, listener)
    end
  end

  context 'status is canceled' do
    let(:requested_status) { 'carrier_canceled' }

    context 'requested begin date and end date are not equal' do
      let(:requested_begin_date) { Date.today.prev_month }
      let(:requested_end_date) { Date.today }

      it 'notifies the listener' do
        expect(listener).to receive(:invalid_dates).with(
          {
            begin_date: request[:begin_date],
            end_date: request[:end_date]
          }
        )
        expect(listener).to receive(:fail)

        subject.execute(request, listener)
      end
    end
  end

  context 'status is terminated' do
    let(:requested_status) { 'carrier_terminated' }
    context 'when begin and end date are equal' do
      let(:requested_begin_date) { Date.today.prev_month }
      let(:requested_end_date) { Date.today.prev_month }
      it 'notifies the listener' do
        expect(listener).to receive(:invalid_dates).with(
          {
            begin_date: request[:begin_date],
            end_date: request[:end_date]
          }
        )
        expect(listener).to receive(:fail)

        subject.execute(request, listener)
      end
    end
  end

  context 'when end date is before start date' do
    let(:requested_begin_date) { Date.today.prev_month }
    let(:requested_end_date) { Date.today.prev_year }
    it 'notifies listener' do
      expect(listener).to receive(:invalid_dates).with(
        {
          begin_date: request[:begin_date],
          end_date: request[:end_date]
        }
      )
      expect(listener).to receive(:fail)

      subject.execute(request, listener)
    end
  end

  context 'when status is invalid' do
    let(:requested_status) { 'bingjiggitybong' }
    it 'notifies listener' do
      expect(listener).to receive(:invalid_status).with({provided: requested_status, allowed: allowed_statuses})
      subject.execute(request, listener)
    end
  end

  context 'when current status is effectuated' do
    let(:subscriber_coverage_status) { 'active' }
    let(:subscriber_coverage_start) { Date.today.prev_month }
    let(:subscriber_coverage_end) { nil }

    context 'and requested status is canceled' do
      let(:requested_status) { 'carrier_canceled' }
      let(:requested_begin_date) { Date.today.prev_month }
      let(:requested_end_date) { Date.today.prev_month }

      it 'sets all enrollee\'s end date' do
        subject.execute(request, listener)  

        enrollees.each do |e|
          expect(e.coverage_end).to eq requested_end_date
        end
      end

      it 'updates enrollee status' do 
        subject.execute(request, listener)

        enrollees.each do |e|
          expect(e.coverage_status).to eq 'inactive'
        end
      end

      it 'sets policy as carrier_canceled' do
        subject.execute(request, listener)

        expect(policy.aasm_state).to eq('carrier_canceled')
      end
    end

    context 'and request status is terminated' do
      let(:requested_status) { 'carrier_terminated' }
      let(:requested_begin_date) { Date.today.prev_month }
      let(:requested_end_date) { Date.today }

      it 'sets all enrollee\'s end date' do
        subject.execute(request, listener)  

        enrollees.each do |e|
          expect(e.coverage_end).to eq requested_end_date
        end
      end

      it 'updates enrollee status' do 
        subject.execute(request, listener)

        enrollees.each do |e|
          expect(e.coverage_status).to eq 'inactive'
        end
      end

      it 'sets policy as carrier_canceled' do
        subject.execute(request, listener)

        expect(policy.aasm_state).to eq('carrier_terminated')
      end
    end
  end

  context 'when current status is canceled' do
    let(:subscriber_coverage_status) { 'inactive' }
    let(:current_status) { 'canceled' }
    let(:subscriber_coverage_start) { Date.today.prev_month }
    let(:subscriber_coverage_end) { Date.today.prev_month }

    context 'and requested_status is effectuated' do
      let(:requested_status) { 'effectuated' }
      let(:requested_begin_date) { Date.today.prev_month }
      let(:requested_end_date) { nil }


      it 'sets enrollee\'s end date' do
        subject.execute(request, listener)  

        enrollees.each do |e|
          expect(e.coverage_end).to eq requested_end_date
        end
      end

      it 'updates enrollee status' do 
        subject.execute(request, listener)

        enrollees.each do |e|
          expect(e.coverage_status).to eq 'active'
        end
      end

      it 'sets policy as effectuated' do
        subject.execute(request, listener)

        expect(policy.aasm_state).to eq('effectuated')
      end

      context 'when an enrollee has a different end date' do
        let(:other_enrollee) do
          Enrollee.new(
            coverage_status: subscriber_coverage_status,
            coverage_start: subscriber_coverage_start,
            coverage_end: subscriber_coverage_end.prev_month
            ) 
        end

        let(:enrollees) {[ subscriber, other_enrollee ]}
        it 'notifies the listener' do
          expect(listener).to receive(:enrollee_end_date_is_different)
          subject.execute(request, listener)
        end

        it 'fails' do
          expect(listener).to receive(:fail)
          subject.execute(request, listener)
        end
      end
    end

    context 'and requested status is terminated' do
      let(:requested_status) { 'carrier_terminated' }
      let(:requested_begin_date) { Date.today.prev_month }
      let(:requested_end_date) { Date.today }

      it 'sets enrollee\'s end date' do
        subject.execute(request, listener)  

        enrollees.each do |e|
          expect(e.coverage_end).to eq requested_end_date
        end
      end

      it 'updates enrollee status' do 
        subject.execute(request, listener)

        enrollees.each do |e|
          expect(e.coverage_status).to eq 'inactive'
        end
      end

      it 'sets policy as terminated' do
        subject.execute(request, listener)

        expect(policy.aasm_state).to eq('carrier_terminated')
      end
    end

  end

  context 'when current status is terminated' do
    let(:subscriber_coverage_status) { 'inactive' }
    let(:current_status) { 'terminated' }
    let(:subscriber_coverage_start) { Date.today.prev_month }
    let(:subscriber_coverage_end) { Date.today.prev_week }

    context 'and requested_status is effectuated' do
      let(:requested_status) { 'effectuated' }
      let(:requested_begin_date) { Date.today.prev_month }
      let(:requested_end_date) { nil }


      it 'sets enrollee\'s end date' do
        subject.execute(request, listener)  

        enrollees.each do |e|
          expect(e.coverage_end).to eq requested_end_date
        end
      end

      it 'updates enrollee status' do 
        subject.execute(request, listener)

        enrollees.each do |e|
          expect(e.coverage_status).to eq 'active'
        end
      end

      it 'sets policy as effectuated' do
        subject.execute(request, listener)

        expect(policy.aasm_state).to eq('effectuated')
      end
    end

    context 'and requested status is canceled' do
      let(:requested_status) { 'carrier_canceled' }
      let(:requested_begin_date) { Date.today.prev_month }
      let(:requested_end_date) { Date.today.prev_month }

      it 'sets enrollee\'s end date' do
        subject.execute(request, listener)  

        enrollees.each do |e|
          expect(e.coverage_end).to eq requested_end_date
        end
      end

      it 'updates enrollee status' do 
        subject.execute(request, listener)

        enrollees.each do |e|
          expect(e.coverage_status).to eq 'inactive'
        end
      end

      it 'sets policy as terminated' do
        subject.execute(request, listener)
        expect(policy.aasm_state).to eq('carrier_canceled')
      end
    end
  end
end