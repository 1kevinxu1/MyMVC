require 'webrick'
require 'byebug'
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/HTTPRequest.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/HTTPResponse.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/Cookie.html

server = WEBrick::HTTPServer.new(Port: 3000)

trap ('INT') {server.shutdown}

server.mount_proc("/") do |request, response|
  debugger
  response.content_type = "text/text"
  response.body = request.unparsed_uri
  response.status = 302
  response['Location'] = "http://www.google.com"
  byebug
end

server.start
