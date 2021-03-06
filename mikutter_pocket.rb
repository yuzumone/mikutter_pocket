# -*- coding: utf-8 -*-

Plugin.create(:mikutter_pocket) do

  defactivity "pocket", "pocket"
  defevent :pocket_request
  defevent :pocket_authorize
  defevent :pocket_add, prototype: [Message]

  # Pocketの認証のためのコードをリクエストするイベント
  on_pocket_request do
    Thread.new {
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
      "https://getpocket.com/auth/authorize?request_token=" +
        params["code"] + "&redirect_uri=https://www.google.com"
    }.next { |url|
      Gtk.openurl(url)
    }.trap{ |e| error e }
  end

  # Pocketの認証をするイベント
  on_pocket_authorize do
    Thread.new {
      uri = URI.parse('https://getpocket.com/v3/oauth/authorize')
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"] = "application/json"
      req["X-Accept"] = "application/json"
      data = {
        "consumer_key" => "48185-0b1cb79c6eaf08bb2b5a6554",
        "code" => UserConfig[:mikutter_pocket_code]
      }.to_json
      req.body = data
      res = https.request(req)
      params = JSON.parse(res.body)
      params["access_token"]
    }.next { |token|
      UserConfig[:mikutter_pocket_token] = token
      UserConfig[:mikutter_pocket_code] = nil
    }.trap{ |e| error e }
  end

  # Pocketに追加するイベント
  on_pocket_add do |msg|
    Thread.new {
      url = "https://twitter.com/#{msg.user[:idname]}/status/#{msg.id}"
      uri = URI.parse('https://getpocket.com/v3/add')
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"] = "application/json"
      req["X-Accept"] = "application/json"
      data = {
        "url" => url,
        "consumer_key" => "48185-0b1cb79c6eaf08bb2b5a6554",
        "access_token" => UserConfig[:mikutter_pocket_token]
      }.to_json
      req.body = data
      res = https.request(req)
      if res.code == '200'
        activity(:pocket, "#{url}をPocketしました")
      else
        activity(:pocket, "#{url}をPocketできませんでした")
      end
    }.trap { |e| error e }
  end

  # PocketのTokenを持っているなら真
  def token?
    UserConfig[:mikutter_pocket_token] != nil ? true : false
  end

  # PocketのCodeを持っているなら真
  def code?
    UserConfig[:mikutter_pocket_code] != nil ? true : false
  end

  command(:mikutter_pocket,
          name: 'Pocket',
          condition: lambda{ |opt| true },
          visible: true,
          role: :timeline) do |opt|
    messages = opt.messages
    if token?
      messages.each do |m|
        Plugin.call(:pocket_add, m)
      end
    elsif code?
      Plugin.call(:pocket_authorize)
      messages.each do |m|
        Plugin.call(:pocket_add, m)
      end
    else
      Plugin.call(:pocket_request)
    end
  end
end
