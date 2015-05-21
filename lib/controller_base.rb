require 'json'
require 'active_support'
require 'active_support/core_ext'
require 'active_support/inflector'
require 'erb'
require 'byebug'

module RailsLite
  class ControllerBase
    attr_reader :req, :res, :params

    # Setup the controller
    def initialize(req, res, route_params = {})
      # debugger
      @req = req
      @res = res
      @already_built_response = false
      @params = Params.new(req, route_params)
    end

    # Helper method to alias @already_built_response
    def already_built_response?
      @already_built_response
    end

    def invoke_action(name)
      raise if already_built_response?
      send(name)
      render(name) unless already_built_response?
    end

    # Set the response status code and header
    def redirect_to(url)
      if already_built_response?
        raise 'Already built a response!'
      else
        @res['Location'] = url
        @res.status = 302
        @already_built_response = true
      end
      session.store_session(@res)
      flash.store_flash(@res)
      # debugger
    end

    def render(template_name)
      contents = File.read("views/#{self.class.to_s.underscore}/#{template_name}.html.erb")
      render_content(ERB.new(contents).result(binding), "text/html")
    end

    def render_content(content, content_type)
      if already_built_response?
        raise 'Already build a response!'
      else
        @res.content_type = content_type
        @res.body = content
        @already_built_response = true
      end
      session.store_session(@res)
      flash.store_flash(@res)
    end

    # method exposing a `Session` object
    def session
      @session ||= Session.new(@req)
    end

    def flash
      @flash ||= Flash.new(@req)
    end
  end

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

  class Session
    # find the cookie for this app
    # deserialize the cookie into a hash
    def initialize(req)
      @session = {}
      req.cookies.each do |cookie|
        @session = JSON.parse(cookie.value) if cookie.name == '_rails_lite_app'
      end
    end

    def [](key)
      @session[key.to_s]
    end

    def []=(key, val)
      @session[key.to_s] = val
    end

    # serialize the hash into json and save in a cookie
    # add to the responses cookies
    def store_session(res)
      @session = WEBrick::Cookie.new('_rails_lite_app', @session.to_json)
      @session.path = "/"
      res.cookies << @session
    end
  end

  class Flash
    def initialize(req)
      @flash_now = {}
      req.cookies.each do |cookie|
        if cookie.name == '_flash_cookie'
          @flash_now = JSON.parse(cookie.value)
        end
      end
      @flash = {}
    end

    def [](value)
      @flash_now[key.to_s]
    end

    def []=(key, val)
      @flash[key.to_s] = val
    end

    def now
      @flash_now
    end

    def store_flash(res)
      @cookie = WEBrick::Cookie.new('_flash_cookie', @flash.to_json)
      @cookie.path = "/"
      res.cookies << @cookie
    end

  end

  class Route
    attr_reader :pattern, :http_method, :controller_class, :action_name

    def initialize(pattern, http_method, controller_class, action_name)
      @pattern = pattern
      @http_method = http_method
      @controller_class = controller_class
      @action_name = action_name
    end

    # checks if pattern matches path and method matches request method
    def matches?(req)
      @pattern =~ req.path && @http_method == req.request_method.downcase.to_sym
    end

    # use pattern to pull out route params (save for later?)
    # instantiate controller and call controller action
    def run(req, res)
      route_params = Hash.new
      regex = @pattern
      debugger
      match_data = regex.match(req.path)
      if match_data
        match_data.names.each do |name|
          route_params[name] = match_data[name]
        end
      end
      @controller = @controller_class.new(req, res, route_params)
      @controller.invoke_action(action_name)

    end
  end

  class Router
    attr_reader :routes

    def initialize
      @routes = []
    end

    # simply adds a new route to the list of routes
    def add_route(pattern, method, controller_class, action_name)
      @routes << Route.new(pattern, method, controller_class, action_name)
    end

    # evaluate the proc in the context of the instance
    # for syntactic sugar :)
    def draw(&proc)
      instance_eval(&proc)
    end

    # make each of these methods that
    # when called add route
    [:get, :post, :put, :delete].each do |http_method|
      define_method(http_method) do |pattern, controller_class, action_name|

        add_route(pattern, http_method, controller_class, action_name)
      end
    end

    # should return the route that matches this request
    def match(req)
      routes.find { |route| route.matches?(req) }
    end

    def resources(path)
      
    end

    # either throw 404 or call run on a matched route
    def run(req, res)
      route = match(req)
      route ? route.run(req, res) : res.status = 404
    end
  end

end
