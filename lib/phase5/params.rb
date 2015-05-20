require 'uri'
require 'byebug'

module Phase5
  class Params
    # use your initialize to merge params from
    # 1. query string
    # 2. post body
    # 3. route params
    #
    # You haven't done routing yet; but assume route params will be
    # passed in as a hash to `Params.new` as below:
    def initialize(req, route_params = {})
      @req = req
      @params = route_params
      parse_www_encoded_form(@req.query_string.to_s)
      parse_www_encoded_form(@req.body.to_s)
    end

    def [](key)
      # @params[key]
      @params[key.to_s]
    end

    def to_s
      @params.to_json.to_s
    end

    class AttributeNotFoundError < ArgumentError; end;

    private
    # this should return deeply nested hash
    # argument format
    # user[address][street]=main&user[address][zip]=89436
    # should return
    # { "user" => { "address" => { "street" => "main", "zip" => "89436" } } }
    def parse_www_encoded_form(www_encoded_form)
      array = URI.decode_www_form(www_encoded_form)
      # debugger
      array.each do |assignments|
        iter_hash = @params
        assignment = parse_key(assignments.first)
        assignment[0...-1].each do |next_key|
          iter_hash[next_key] = Hash.new unless iter_hash.keys.include?(next_key)
          iter_hash = iter_hash[next_key]
        end
        iter_hash[assignment[-1]] = assignments.last
      end
    end

    # this should return an array
    # user[address][street] should return ['user', 'address', 'street']
    def parse_key(key)
      keys = key.split("[")
      keys.map do |key|
        key[-1] == ']' ? key[0...-1] : key
      end
    end
  end
end
