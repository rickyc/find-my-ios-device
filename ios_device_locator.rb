require 'base64'
require 'json'
require 'net/http'
require 'net/https'
require 'ostruct'
require 'typhoeus'
require 'uri'

class IOSDeviceLocator

  def initialize username, password
    @username = username
    @password = password
    @partition = nil
    @baseURI = "/fmipservice/device/#{@username}/"
    @initClient = "initClient"
    @refreshClient = "refreshClient"
    @sendMessage = "sendMessage"
    @remoteLock = "remoteLock"
    @remoteWipe = "remoteWipe"
    @removeDevice = "remove"
    @saveLocFoundPref = "saveLocFoundPref"
    @playSound = "playSound"
    @setDeviceAsLost = "lostDevice"
    getPartition
  end

  def getDevicesAndLocations
    response = post(@initClient)
    puts 
    devices_json = JSON.parse(response.body)['content']
    devices_json.collect { |device| hash_to_device(device) }
  end

  def updateDevicesAndLocations
    resposne = post(@refreshClient)
    puts
    devices_json = JSON.parse(response.body)['content']
    devices_json.collect { |device| hash_to_device(device) }
  end

  def removeDevice(deviceid)
    options = {
      'device'=>deviceid
    }
    post(@removeDevice, options)
  end
  
  def playSound(deviceid,subject)
    options = {
      'device'=>deviceid, 
      'subject'=>subject
    }
    post(@playSound,options)
  end 
  
  def saveLocFoundPref(deviceid,locFoundEnabled=true)
    options = {
      'device'=>deviceid,
      'locFoundEnabled'=>locFoundEnabled
    }
    post(@saveLocFoundPref, options)
  end

  def sendMessage(deviceid,subject="",text="",sound=false)
    options = {
      'device'=>deviceid, 
      'sound' => sound, 
      'subject'=>subject,  
      'text'=>text,
      'userText'=>true
    }
    response = post(@sendMessage,options)
  end

  def remoteLock(deviceid,oldPasscode="",passcode="")
    options = {
      'device'=>deviceid,
      'oldPasscode'=>oldPasscode,
      'passcode'=>passcode
    }
    response = post(@remoteLock,options)    
  end

  def remoteWipe(devicedid)
    options = {
      'device'=>deviceid
    }
    post(@remoteWipe,deviceid)
  end
  
  def setDeviceAsLost(deviceid,text="", sound=false,trackingEnabled=true,ownerNbr="",emailUpdates=true,lostModeEnabled=true)
    options = {
      'device'=>deviceid, 
      'text'=>text,
      'sound' => sound, 
      'trackingEnabled' => trackingEnabled,
      'ownerNbr' => ownerNbr,
      'emailUpdates' => emailUpdates,
      'lostModeEnabled' => lostModeEnabled,
      'userText'=> text.empty? ? false : true
    }
    post(@setDeviceAsLost, options)
  end

  private

  def getPartition
    response = post(@initClient)
    @partition = response.headers['X-Apple-MMe-Host']
  end

  def post(url,options=nil)
    uri = @partition ? "https://#{@partition}#{@baseURI}#{url}" : "https://fmipmobile.icloud.com#{@baseURI}#{url}"
    headers = {
      'Authorization' => "Basic #{Base64.encode64("#{@username}:#{@password}").chomp!}",
      'Content-Type' => 'application/json; charset=utf-8',
      'X-Apple-Find-Api-Ver' => '2.0',
      'X-Apple-Authscheme' => 'UserIdGuest',
      'X-Apple-Realm-Support' => '1.0',
      'User-Agent' => 'Find iPhone/1.4 MeKit (iPad: iPhone OS/4.2.1)',
      'X-Client-Name' => 'iPad',
      'X-Client-UUID' => '0cf3dc501ff812adb0b202baed4f37274b210853',
      'Accept-Language' => 'en-us',
      'Connection' => 'keep-alive'
    }
    unless options.nil?
      clientContext = { 
        'clientContext' => {
          'appName'=>'FindMyiPhone',
          'appVersion'=>'2.0.2',
          'shouldLocate'=>false
        }
      }
      body = JSON.generate(clientContext.merge(options)) 

      Typhoeus::Request.post(uri, headers: headers, followlocation: true, verbose: true, maxredirs: 10, :body => body)
    else
      Typhoeus::Request.post(uri, headers: headers, followlocation: true, verbose: true, maxredirs: 10)
    end
  end

  def hash_to_device(hsh)
    device = OpenStruct.new
    device.id = hsh['id']
    device.name = hsh['name']
    device.class = hsh['deviceClass']
    device.display_name = hsh['deviceDisplayName']
    device.model = hsh['deviceModel']

    if (location = hsh['location'])
      device.latitude = location['latitude']
      device.longitude = location['longitude']
      device.time = location['timeStamp']
    end
    
    device
  end

end


# USAGE: $ ./ruby ios_device_locator username password
if __FILE__ == $0
  r = IOSDeviceLocator.new(ARGV[0], ARGV[1])
  devices = r.getDevicesAndLocations
  devices.each { |d| puts "#{d.name} - (#{d.latitude}, #{d.longitude})" }
end
