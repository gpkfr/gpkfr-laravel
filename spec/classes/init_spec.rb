require 'spec_helper'
describe 'laravel' do

  context 'with defaults for all parameters' do
    it { should contain_class('laravel') }
  end
end
