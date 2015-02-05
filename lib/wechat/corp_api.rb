require 'wechat/client'
require 'wechat/access_token'

class Wechat::CorpAccessToken < Wechat::AccessToken
  def refresh
    data = client.get("gettoken", params:{corpid: appid, corpsecret: secret})
    File.open(token_file, 'w'){|f| f.write(data.to_s)} if valid_token(data)
    return @token_data = data
  end
end

class Wechat::CorpApi
  attr_reader :access_token, :client

  API_BASE = "https://qyapi.weixin.qq.com/cgi-bin/"

  def initialize appid, secret, token_file
    @client = Wechat::Client.new(API_BASE)
    @access_token = Wechat::CorpAccessToken.new(@client, appid, secret, token_file)
  end

  def user userid
    get('user/get', params: {userid: userid})
  end

  def menu_create menu, agentid
    # 微信不接受7bit escaped json(eg \uxxxx), 中文必须UTF-8编码, 这可能是个安全漏洞
    post("menu/create", JSON.generate(menu), {params: {agentid: agentid}})
  end

  def message_send(message)
    post "message/send", message.to_json, content_type: :json
  end

  protected
  def get path, headers={}
    with_access_token(headers[:params]){|params| client.get path, headers.merge(params: params)}
  end

  def post path, payload, headers = {}
    with_access_token(headers[:params]){|params| client.post path, payload, headers.merge(params: params)}
  end

  def with_access_token params={}, tries=2
    begin
      params ||= {}
      yield(params.merge(access_token: access_token.token))
    rescue Wechat::AccessTokenExpiredError => ex
      access_token.refresh
      retry unless (tries -= 1).zero?
    end
  end

end
