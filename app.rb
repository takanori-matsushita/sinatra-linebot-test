require 'sinatra'
require 'sinatra/reloader'
require 'line/bot'
require 'dotenv'

Dotenv.load

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_id = ENV["LINE_CHANNEL_ID"]
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

def get_shop_list(event)
  lat = event.message['latitude']
  lng = event.message['longitude']
  key = ENV["HOTPEPPER_API_KEY"]
  uri = URI.parse("http://webservice.recruit.co.jp/hotpepper/gourmet/v1/?key=#{key}&format=json&lat=#{lat}&lng=#{lng}")
  res = Net::HTTP.get_response(uri) # APIを呼び出す
  return nil if res.code != "200" # エラーが発生したらnilを返す
  shops = JSON.parse(res.body) # APIの結果をJSON形式として読み出す
  return nil if shops.length == 0 # 該当した書籍が0件の場合はnilを返す
  return shops['results']['shop'].map do |shop|
    {
      "thumbnailImageUrl": shop['photo']['mobile']['l'],
      "imageBackgroundColor": "#FFFFFF",
      "title": shop['name'],
      "text": shop['address'],
      "defaultAction": {
          "type": "uri",
          "label": "View detail",
          "uri": shop['urls']['pc']
      },
      "actions": [
          {
              "type": "uri",
              "label": "ホットペッパーを見る",
              "uri": shop['urls']['pc']
          }
      ]
    }
  end
end

def res_location
  {
    "type": "template",
    "altText": "location",
    "template": {
      "type": "buttons",
      "title": "位置情報",
      "text": "このBOTは位置情報から周囲の飲食店を紹介するBOTです。位置情報を送ってください。",
      "defaultAction": {
        "type": "uri",
        "label": "View detail",
        "uri": "https://arukayies.com/"
      },
      "actions": [
        {
          "type": "location",
          "label": "現在地を選択してください。"
        }
      ]
    }
  }
end

def create_flex_messages(shops)
  {
    "type": "template",
    "altText": "this is a carousel template",
    "template": {
        "type": "carousel",
        "columns": shops,
        "imageAspectRatio": "rectangle",
        "imageSize": "cover"
    }
  }
end

get '/' do
  'hello sinatra-line-bot'
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each do |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        message = res_location()
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Location
        shops = get_shop_list(event)
        message = create_flex_messages(shops)
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    end
  end
  # Don't forget to return a successful response
  "OK"
end