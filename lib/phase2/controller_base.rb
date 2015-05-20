module Phase2
  class ControllerBase
    attr_reader :req, :res

    # Setup the controller
    def initialize(req, res)
      @req = req
      @res = res
      @already_built_response = false
    end

    # Helper method to alias @already_built_response
    def already_built_response?
      @already_built_response
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
    end

    # Populate the response with content.
    # Set the response's content type to the given type.
    # Raise an error if the developer tries to double render.
    def render_content(content, content_type)
      if already_built_response?
        raise 'Already build a response!'
      else
        @res.content_type = content_type
        @res.body = content
        @already_built_response = true
      end
    end

    def render(template_name)
      contents = File.read("views/#{self.class.to_s.underscore}/#{template_name}.html.erb")
      render_content(ERB.new(contents).result(binding), "text/html")
    end
  end
end
