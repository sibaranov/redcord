# frozen_string_literal: true

# typed: false

describe Redcord::Attribute do
  let!(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :a, Integer
      attribute :b, T.nilable(Integer), index: true
    end
  end

  let!(:another_klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      ttl 2.hour

      attribute :boolean, T::Boolean, index: true
      attribute :float, Float, index: true
      attribute :integer, Integer, index: true
      attribute :string, String, index: true
      attribute :symbol, Symbol, index: true
      attribute :time, Time, index: true
    end
  end

  it 'defines props' do
    instance = klass.new(a: 1)

    %i[a b].each do |attribute|
      expect(instance.methods.include?(attribute)).to be true
      expect(instance.methods.include?(:"#{attribute}=")).to be true
    end

    expect(instance.id).to be_nil
  end

  it 'adds attributes to the classes' do
    expect(
      klass.class_variable_get(:@@range_index_attributes),
    ).to eq(Set.new([:b]))

    expect(
      another_klass.class_variable_get(:@@index_attributes),
    ).to eq(Set.new(%i[boolean string symbol]))

    expect(
      another_klass.class_variable_get(:@@range_index_attributes),
    ).to eq(Set.new(%i[float integer time]))

    expect(
      another_klass.class_variable_get(:@@ttl),
    ).to eq(2.hour)
  end
end
