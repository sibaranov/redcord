# frozen_string_literal: true

# typed: false

shared_examples :redcord_relation_tests do
  let(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :a, Integer, index: true
      attribute :b, String, index: true
      attribute :c, Integer
      attribute :d, T.nilable(Time), index: true

      def self.name
        'RedcordSpecModel'
      end
    end
  end

  before(:each) do
    klass.establish_connection
  end

  it 'maintains index id sets after an update operation' do
    instance = klass.create!(a: 3, b: '3', c: 3)
    instance.update!(a: 4)

    # query for previous value of a should be empty, and new value should be
    # updated.
    expect(klass.where(a: 3).count).to eq 0

    queried_instances = klass.where(a: 4)
    expect(queried_instances.size).to eq 1
    expect(queried_instances.first.id).to eq instance.id

    # other index attributes not changed should be untouched
    queried_instances = klass.where(b: '3')
    expect(queried_instances.count).to eq 1
    expect(queried_instances.first.id).to eq instance.id
  end

  it 'maintains index id sets after delete operation' do
    instance = klass.create!(a: 3, b: '3', c: 3)
    instance.destroy

    queried_instances = klass.where(a: 3)
    expect(queried_instances.size).to eq 0
  end

  it 'supports chaining select index query method' do
    first = klass.create!(a: 3, b: '3', c: 3)
    klass.create!(a: 3, b: '4', c: 3)

    queried_instances = klass.where(a: 3, b: '3').select(:c)
    expect(queried_instances.size).to eq 1
    expect(queried_instances[0][:id]).to eq(first.id)
    expect(queried_instances[0][:a]).to be_nil
    expect(queried_instances[0][:b]).to be_nil
    expect(queried_instances[0][:c]).to eq(3)
  end

  it 'does not chain the select method if a block is given' do
    first = klass.create!(a: 3, b: '3', c: 3)
    klass.create!(a: 3, b: '4', c: 3)

    queried_instances = klass.where(a: 3).select { |r| r.b == '3' }
    expect(queried_instances.size).to eq 1
    expect(queried_instances[0].id).to eq(first.id)
  end

  it 'supports chaining count index query method' do
    klass.create!(a: 3, b: '3', c: 3)
    klass.create!(a: 3, b: '4', c: 3)

    count = klass.where(a: 3).count
    expect(count).to eq 2

    expect(klass.where(a: 0).count).to eq 0
  end
end

describe Redcord::Relation do
  context '1 shard' do
    include_examples :redcord_relation_tests
  end

  context '3 shards' do
    before(:each) do
      Redcord::Base.redis = Redcord::Redis.new(
        cluster: (0...3).map { |i| {db: i} },
      )
    end

    include_examples :redcord_relation_tests
  end
end
