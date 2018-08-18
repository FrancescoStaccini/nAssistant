
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('Application/json')


--------------------------------------------------------------------------
---------------------------------------------------------------------------
local ga_module = {}

local request = {}
local response = {}

--"suggestions_strings" deve essere un array di stringhe & "card" deve essere creata con create_card()
local function fill_response(speech_text, display_text, expect_response, suggestions_strings, card)  

  if display_text == nil or display_text == "" then display_text = speech_text end
  if expect_response == nil then expect_response = true end

  local mysuggestions = {}--MAX 10 (imposto da google)

  if suggestions_strings then 
    for i = 1, #suggestions_strings do
      table.insert( mysuggestions, {title = suggestions_strings[i]} )
    end
  end

  local myitems = {}

  if card then
    tprint(card)
    myitems =  {
      { 
        simpleResponse = {
          textToSpeech = speech_text,
          displayText = display_text 
        } 
      },
      {basicCard = card}
    }  
  else
    myitems[1] =  {
      simpleResponse = {
        textToSpeech = speech_text,
        displayText = display_text,
      }
    } 
  end
  
  local r = {}
  --se è stato impostato un context: lo consumo 
  local mycontext = ga_module.getContext()
  if mycontext then 

    r = {
      fulfillmentText = display_text,
      payload = {
        google = {
          expectUserResponse = expect_response,
          richResponse = {
            items = myitems,
            suggestions = mysuggestions
          }
        } 
      },
      outputContexts = mycontext
    }

    ga_module.deleteContext()
  else
    r = {
      fulfillmentText = display_text,
      payload = {
        google = {
          expectUserResponse = expect_response,
          richResponse = {
            items = myitems,
            suggestions = mysuggestions
          }
        } 
      }
    }

  end


  --TODO: print fatta a modo per il debug

  return json.encode(r)
end


--TODO: migliora! le card permettono sottotitoli, + bottoni, integrazioni ecc. [ https://dialogflow.com/docs/rich-messages#card ]
function ga_module.create_card(card_title, card_url_image, accessibility_image_text, button_title, button_open_url_action  )

  local myButton = {}
  myButton = { 
    {
      title = button_title,
      openUrlAction = { url = button_open_url_action}
     } 
  }

  local myCard = {}
  myCard = {
    title = card_title,
    image = { url = card_url_image, accessibilityText = accessibility_image_text },
    buttons = myButton
  }

  return myCard
end

--per mettere un contesto fittizzio (deciso via codice e non dall'agentdialogflow) basta chiamare setContext!

--qui uso un paradigma diverso: non restituisco la struttura (come nella card) ma salvo
--nei prefs. se ho strutture complesse dovrò usare tanti prefs quanti sono i campi da salvare
function ga_module.setContext(name, lifespan, parameter) --TODO: SUPPORTO PER PIÙ PARAMETRI
  local ok = nil

  if name then 
    ok = ntop.setCache("context_name", name, 60 * 20) --(un context dura almassimo 20min, dice google )
    if not ok then return nil end
  end
  if lifespan then 
    ok = ntop.setCache("context_lifespan", lifespan, 60 * 20)
    if not ok then return nil end
  end
  if parameter then 
    ok = ntop.setCache("context_param", parameter, 60*20)
    if not ok then return nil end
  end

  if ok then return true else return nil end
end


function ga_module.deleteContext()
  ntop.delCache("context_name")
  ntop.delCache("context_lifespan")
  ntop.delCache("context_param")
end


function ga_module.getContext()
  local id = ntop.getCache("session_id") 

  if id == "" then return nil end

  local name = ntop.getCache("context_name")
  if name == "" then return nil end

  local lifespan = ntop.getCache("context_lifespan")
  if lifespan == "" then lifespan = 2 end

  local mycontext = {
    {
      name = id .."/contexts/"..name,
      lifespanCount = lifespan,
      parameters = {param = ntop.getCache("context_param") }
    }
  }

  return mycontext
end

function ga_module.send(speech_text, display_text, expect_response, suggestions_strings, card )

  res = fill_response(speech_text, display_text,expect_response, suggestions_strings, card)
  print(res.."\n")

  io.write("\n")
  tprint(res)
  io.write("\n")
end


function ga_module.receive()

  local info, pos, err = json.decode(_POST["payload"], 1, nil)--sto assumento che esiste SOLO un outputContext
  --TODO: gestione errori json ed eventuali campi nil (tipo context o parameters)
  
  response["responseId"] = info.responseId
  response["queryText"] = info.queryResult.queryText
  if info.queryResult.parameters ~= nil then response["parameters"] = info.queryResult.parameters end
  
  ---response["outputContext_name"] = info.queryResult.outputContexts[1].name  
  --response["outputContext_parameters"] = info.queryResult.outputContexts[1].parameters.number
  response["intent_name"] = info.queryResult.intent.displayName
  response["session"] = info.session
  
  --tprint(response)

  ntop.setCache("session_id", info.session )

  return response
end

return ga_module