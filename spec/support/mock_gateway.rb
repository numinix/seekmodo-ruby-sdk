# frozen_string_literal: true

require "json"
require "faraday"
require "faraday/adapter/test"

TENANT_ID = "redline"
SECRET = "super-secret-key"
FIXTURES_DIR = File.expand_path("../contracts/fixtures", __dir__)

def load_fixture(name)
  path = File.join(FIXTURES_DIR, name)
  JSON.parse(File.read(path))
end

class MockGateway
  attr_reader :requests

  def initialize
    @responses = []
    @requests = []
    @stubs = Faraday::Adapter::Test::Stubs.new
    @connection = Faraday.new(url: "https://mcp.seekmodo.com") do |f|
      f.adapter :test, @stubs
    end

    @stubs.post(%r{.*}) do |env|
      @requests << env
      if @responses.empty?
        [500, {}, JSON.generate({ "error" => "no mock response queued" })]
      else
        status, body = @responses.shift
        [status, {}, JSON.generate(body)]
      end
    end

    @stubs.get(%r{.*}) do |env|
      @requests << env
      if @responses.empty?
        [500, {}, JSON.generate({ "error" => "no mock response queued" })]
      else
        status, body = @responses.shift
        [status, {}, JSON.generate(body)]
      end
    end
  end

  def push_response(status, body)
    @responses << [status, body]
  end

  def last_request
    raise "No requests recorded" if @requests.empty?

    @requests.last
  end

  def make_client
    signer = Seekmodo::Sdk::HmacSigner.new(TENANT_ID, SECRET)
    Seekmodo::Sdk::Connector::Client.new(signer, connection: @connection)
  end
end
