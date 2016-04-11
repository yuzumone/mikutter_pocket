# -*- coding: utf-8 -*-

Plugin.create(:mikutter_pocket) do

  defactivity "pocket", "pocket"

  def request
    Thread.start do
      uri = URI.parse('https://getpocket.com/v3/oauth/request')

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)

      req["Content-Type"] = "application/json"
      req["X-Accept"] = "application/json"
      data = {
          "consumer_key" => "48185-0b1cb79c6eaf08bb2b5a6554",
          "redirect_uri" => "https://www.google.com"
      }.to_json

      req.body = data
      res = https.request(req)
      params = JSON.parse(res.body)
      UserConfig[:mikutter_pocket_code] = params["code"]
      url = "https://getpocket.com/auth/authorize?request_token=" +
          params["code"] + "&redirect_uri=" + "https://www.google.com"

      ::Gtk::TimeLine.openurl(url)
    end
  end

  def authorize
    Thread.start do
      oauth_uri = URI.parse('https://getpocket.com/v3/oauth/authorize')
      oauth_https = Net::HTTP.new(oauth_uri.host, oauth_uri.port)
      oauth_https.use_ssl = true
      oauth_req = Net::HTTP::Post.new(oauth_uri.request_uri)

      oauth_req["Content-Type"] = "application/json"
      oauth_req["X-Accept"] = "application/json"
      oauth_data = {
          "consumer_key" => "48185-0b1cb79c6eaf08bb2b5a6554",
          "code" => UserConfig[:mikutter_pocket_code]
      }.to_json

      oauth_req.body = oauth_data
      oauth_res = oauth_https.request(oauth_req)
      oauth_params = JSON.parse(oauth_res.body)
      UserConfig[:mikutter_pocket_token] = oauth_params["access_token"]
      UserConfig[:mikutter_pocket_code] = nil
    end
  end

  def add(url)
    Thread.start do
      add_uri = URI.parse('https://getpocket.com/v3/add')
      add_https = Net::HTTP.new(add_uri.host, add_uri.port)
      add_https.use_ssl = true
      add_req = Net::HTTP::Post.new(add_uri.request_uri)

      add_req["Content-Type"] = "application/json"
      add_req["X-Accept"] = "application/json"
      add_data = {
          "url" => url,
          "consumer_key" => "48185-0b1cb79c6eaf08bb2b5a6554",
          "access_token" => UserConfig[:mikutter_pocket_token]
      }.to_json

      add_req.body = add_data
      add_res = add_https.request(add_req)

      if add_res.code == '200'
        activity(:pocket, "#{url}をPocketしたよ")
      else
        activity(:pocket, "#{url}をPocketできなかったよ")
      end
    end
  end

  command(:mikutter_pocket,
          name: 'Pocket',
          condition: Plugin::Command[:HasOneMessage],
          visible: true,
          role: :timeline) do |opt|
    message = opt.messages.first
    screen_name = message.user[:idname]
    url = "https://twitter.com/#{screen_name}/status/#{message.id}"

    if UserConfig[:mikutter_pocket_token] == nil
      if UserConfig[:mikutter_pocket_code] == nil
        request
      else
        authorize
        add(url)
      end
    else
      add(url)
    end
  end
end
