--[[
	This is LXSC 0.14,  which is licensed under the MIT license.
	https://github.com/Phrogz/LXSC
]]

local LXSC = {
	VERSION="0.14",
	scxmlNS="http://www.w3.org/2005/07/scxml"
}

-- Horribly simple xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
function LXSC.uuid4()
	return table.concat({
		string.format('%04x', math.random(0, 0xffff))..string.format('%04x',math.random(0, 0xffff)),
		string.format('%04x', math.random(0, 0xffff)),
		string.format('4%03x',math.random(0, 0xfff)),
		string.format('a%03x',math.random(0, 0xfff)),
		string.format('%06x', math.random(0, 0xffffff))..string.format('%06x',math.random(0, 0xffffff))
	},'-')
end











LXSC.State={}; LXSC.State.__meta = {__index=LXSC.State}

setmetatable(LXSC.State,{__index=function(s,k) error("Attempt to access "..tostring(k).." on state") end})

LXSC.State.stateKinds = {state=1,parallel=1,final=1,history=1,initial=1}
LXSC.State.realKinds  = {state=1,parallel=1,final=1}
LXSC.State.aggregates = {datamodel=1,donedata=1}
LXSC.State.executes   = {onentry='_onentrys',onexit='_onexits'}

function LXSC:state(kind)
	local t = {
		_kind       = kind or 'state',
		id          = kind.."-"..self.uuid4(),
		isAtomic    = true,
		isCompound  = false,
		isParallel  = kind=='parallel',
		isHistory   = kind=='history',
		isFinal     = kind=='final',
		ancestors   = {},

		states      = {},
		reals       = LXSC.List(), -- <state>, <parallel>, and <final> children only
		transitions = LXSC.List(),
		_eventlessTransitions = {},
		_eventedTransitions   = {},

		_onentrys   = {},
		_onexits    = {},
		_datamodels = {},
		_donedatas  = {},
		_invokes    = {}
	}
	if kind=='history' then t.type='shallow' end -- default value
	t.selfAndAncestors={t}
	return setmetatable(t,self.State.__meta)
end

function LXSC.State:attr(name,value)
	if name=="name" or name=="id" or name=="initial" then
		self[name] = value
	else
		-- local was = rawget(self,name)
		-- if was~=nil and was~=value then print(string.format("Warning: updating state %s=%s with %s=%s",name,tostring(self[name]),name,tostring(value))) end
		self[name] = value
	end
end

function LXSC.State:addChild(item)
	if item._kind=='transition' then
		item.source = self
		table.insert( self.transitions, item )

	elseif self.aggregates[item._kind] then
		item.state = self

	elseif self.executes[item._kind] then
		item.state = self
		table.insert( self[self.executes[item._kind]], item )

	elseif self.stateKinds[item._kind] then
		table.insert(self.states,item)
		item.parent = self
		item.ancestors[1] = self
		item.ancestors[self] = true
		item.selfAndAncestors[2] = self
		for i,anc in ipairs(self.ancestors) do
			item.ancestors[i+1]        = anc
			item.ancestors[anc]        = true
			item.selfAndAncestors[i+2] = anc
		end
		if self.realKinds[item._kind] then
			table.insert(self.reals,item)
			self.isCompound = self._kind~='parallel'
			self.isAtomic   = false
		end

	elseif item._kind=='invoke' then
		item.state = self
		table.insert(self._invokes,item)

	else
		-- print("Warning: unhandled child of state: "..item._kind )
	end
end

function LXSC.State:ancestorsUntil(stopNode)
	local i=0
	return function()
		i=i+1
		if self.ancestors[i] ~= stopNode then
			return self.ancestors[i]
		end
	end
end

function LXSC.State:createInitialTo(stateOrId)
	local initial = LXSC:state('initial')
	self:addChild(initial)
	local transition = LXSC:transition()
	initial:addChild(transition)
	transition:addTarget(stateOrId)
	transition._target = type(stateOrId)=='string' and stateOrId or stateOrId.id
	self.initial = initial
end

function LXSC.State:convertInitials()
	local init = rawget(self,'initial')
	if type(init)=='string' then
		-- Convert initial="..." attribute to <initial> state
		self:createInitialTo(self.initial)
	elseif not init then
		local initialElement
		for _,s in ipairs(self.states) do
			if s._kind=='initial' then initialElement=s; break end
		end

		if initialElement then
			self.initial = initialElement
		elseif self.states[1] then
			self:createInitialTo(self.states[1])
		end
	end
	for _,s in ipairs(self.reals) do s:convertInitials() end
end

function LXSC.State:cacheReference(lookup)
	lookup[self.id] = self
	for _,s in ipairs(self.states) do s:cacheReference(lookup) end
end

function LXSC.State:resolveReferences(lookup)
	for _,t in ipairs(self.transitions) do
		if t.targets then
			for i,target in ipairs(t.targets) do
				if type(target)=="string" then
					if lookup[target] then
						t.targets[i] = lookup[target]
					else
						error(string.format("Cannot find start with id '%s' for target",tostring(target)))
					end
				end
			end
		end
	end
	for _,s in ipairs(self.states) do s:resolveReferences(lookup) end
end

function LXSC.State:descendantOf(possibleAncestor)
	return self.ancestors[possibleAncestor]
end

function LXSC.State:inspect()
	return string.format("<%s id=%s>",tostring(rawget(self,'_kind')),tostring(rawget(self,'id')))
end

-- ********************************************************

-- These elements pass their children through to the appropriate collection on the state
for kind,collection in pairs{ datamodel='_datamodels', donedata='_donedatas' } do
	LXSC[kind] = function()
		local t = {_kind=kind}
		function t:addChild(item)
			table.insert(self.state[collection],item)
		end
		return t
	end
end










LXSC.SCXML={}; LXSC.SCXML.__meta = {__index=LXSC.SCXML}
setmetatable(LXSC.SCXML,{__index=LXSC.State})

function LXSC:scxml()
	local t = LXSC:state('scxml')
	t.name      = "(lxsc)"
	t.binding   = "early"
	t.datamodel = "lua"
	-- t.id        = nil

	t.running   = false
	t._configuration = LXSC.OrderedSet()

	return setmetatable(t,LXSC.SCXML.__meta)
end

-- Fetch a single named value from the data model
function LXSC.SCXML:get(location)
	return self._data:get(location)
end

-- Set a single named value in the data model
function LXSC.SCXML:set(location,value)
	return self._data:set(location,value)
end

-- Evaluate a single Lua expression and return the value
function LXSC.SCXML:eval(expression)
	return self._data:eval(expression)
end

-- Run arbitrary script code (multiple lines) with no return value
function LXSC.SCXML:run(code)
	return self._data:run(code)
end

function LXSC.SCXML:isActive(stateId)
	if not rawget(self,'_stateById') then self:expandScxmlSource() end
	return self._configuration[self._stateById[stateId]]
end

function LXSC.SCXML:activeStateIds()
	local a = LXSC.OrderedSet()
	for _,s in ipairs(self._configuration) do a:add(rawget(s,'id') or rawget(s,'name')) end
	return a
end

function LXSC.SCXML:activeAtomicIds()
	local a = LXSC.OrderedSet()
	for _,s in ipairs(self._configuration) do
		if s.isAtomic then a:add(s.id) end
	end
	return a
end

function LXSC.SCXML:allEvents()
	local all = {}
	local function crawl(state)
		for _,s in ipairs(state.states) do
			for _,t in ipairs(s._eventedTransitions) do
				for _,e in ipairs(t.events) do
					all[e.name] = true
				end
			end
			crawl(s)
		end
	end
	crawl(self)
	return all
end

function LXSC.SCXML:availableEvents()
	local all = {}
	for _,s in ipairs(self._configuration) do
		for _,t in ipairs(s._eventedTransitions) do
			for _,e in ipairs(t.events) do
				all[e.name] = true
			end
		end
	end
	return all
end

function LXSC.SCXML:allStateIds()
	if not rawget(self,'_stateById') then self:expandScxmlSource() end
	local stateById = {}
	for id,s in pairs(self._stateById) do
		if s._kind~="initial" then stateById[id]=s end
	end
	return stateById
end

function LXSC.SCXML:atomicStateIds()
	if not rawget(self,'_stateById') then self:expandScxmlSource() end
	local stateById = {}
	for id,s in pairs(self._stateById) do
		if s.isAtomic and s._kind~="initial" then stateById[id]=s end
	end
	return stateById
end

function LXSC.SCXML:addChild(item)
	if item._kind=='script' then
		self._script = item
	else
		LXSC.State.addChild(self,item)
	end
end

-- Wrap os.clock() as SCXML:elapsed() so that clients can override with own implementation if desired
LXSC.SCXML.elapsed = os.clock










LXSC.Transition={}
LXSC.Transition.__meta = {
	__index=LXSC.Transition,
	__tostring=function(t) return t:inspect() end
}
local validTransitionFields = {targets=1,cond=1,_target=1}
setmetatable(LXSC.Transition,{__index=function(s,k) if not validTransitionFields[k] then error("Attempt to access '"..tostring(k).."' on transition "..tostring(s)) end end})

function LXSC:transition()
	local t = { _kind='transition', _exec={}, type="external" }
	setmetatable(t,self.Transition.__meta)
	return t
end

function LXSC.Transition:attr(name,value)
	if name=='event' then
		self.events = {}
		self._event = value
		for event in string.gmatch(value,'[^%s]+') do
			local tokens = {}
			for token in string.gmatch(event,'[^.*]+') do table.insert(tokens,token) end
			tokens.name = table.concat(tokens,'.')
			table.insert(self.events,tokens)
		end

	elseif name=='target' then
		self.targets = nil
		self._target = value
		for target in string.gmatch(value,'[^%s]+') do self:addTarget(target) end

	elseif name=='cond' or name=='type' then
		self[name] = value

	else
		-- local was = rawget(self,name)
		-- if was~=nil and was~=value then print(string.format("Warning: updating transition %s=%s with %s=%s",name,tostring(self[name]),name,tostring(value))) end
		self[name] = value

	end
end

function LXSC.Transition:addChild(item)
	table.insert(self._exec,item)
end

function LXSC.Transition:addTarget(stateOrId)
	if not self.targets then self.targets = LXSC.List() end
	if type(stateOrId)=='string' then
		for id in string.gmatch(stateOrId,'[^%s]+') do
			table.insert(self.targets,id)
		end
	else
		table.insert(self.targets,stateOrId)
	end
end

function LXSC.Transition:conditionMatched(datamodel)
	if self.cond then
		local result = datamodel:eval(self.cond)
		return result and (result ~= LXSC.Datamodel.EVALERROR)
	end
	return true
end

function LXSC.Transition:matchesEvent(event)
	for _,tokens in ipairs(self.events) do
		if event.name==tokens.name or tokens.name=="*" then
			return true
		elseif #tokens <= #event._tokens then
			local matched = true
			for i,token in ipairs(tokens) do
				if event._tokens[i]~=token then
					matched = false
					break
				end
			end
			if matched then
				-- print("Transition",self._event,"matched",event.name)
				return true
			end
		end
	end
	-- print("Transition",self._event,"does not match",event.name)
end

function LXSC.Transition:inspect(detailed)
	local targets
	if self.targets then
		targets = {}
		for i,s in ipairs(self.targets) do targets[i] = s.id end
	end
	if detailed then
		return string.format(
			"<transition in '%s'%s%s%s type=%s>",
			self.source.id or self.source.name,
			rawget(self,'_event')  and (" on '"..self._event.."'")  or "",
			rawget(self,'cond')    and (" if '"..self.cond.."'")    or "",
			targets and (" target='"..table.concat(targets,' ').."'") or " TARGETLESS",
			self.type
		)
	else
		return string.format(
			"<transition%s%s%s %s>",
			rawget(self,'_event')  and (" event='"..self._event.."'")  or "",
			rawget(self,'cond')    and (" cond='"..self.cond.."'")    or "",
			targets and (" target='"..table.concat(targets,' ').."'") or " TARGETLESS",
			self.type
		)
	end
end










LXSC.Datamodel = {}; LXSC.Datamodel.__meta = {__index=LXSC.Datamodel}

setmetatable(LXSC.Datamodel,{__call=function(dm,scxml,scope)
	if not scope then scope = {} end
	function scope.In(id) return scxml:isActive(id) end
	return setmetatable({ statesInited={}, scxml=scxml, scope=scope, cache={} },dm.__meta)
end})

function LXSC.Datamodel:initAll()
	local function recurse(state)
		self:initState(state)
		for _,s in ipairs(state.reals) do recurse(s) end
	end
	recurse(self.scxml)
end

function LXSC.Datamodel:initState(state)
	if not self.statesInited[state] then
		for _,data in ipairs(state._datamodels) do
			local value, err
			if data.src then
				local colon = data.src:find(':')
				local scheme,hierarchy = data.src:sub(1,colon-1), data.src:sub(colon+1)
				if scheme=='file' then
					local f,msg = io.open(hierarchy,"r")
					if not f then
						self.scxml:fireEvent("error.execution.invalid-file",msg)
					else
						value = self:eval(f:read("*all"))
						f:close()
					end
				else
					self.scxml:fireEvent("error.execution.invalid-data-scheme","LXSC does not support <data src='"..scheme..":...'>")
				end
			else
				value = self:eval(data.expr or tostring(data._text))
			end

			if value~=LXSC.Datamodel.EVALERROR then 
				self:set( data.id, value )
			else
				self:set( data.id, nil )
			end
		end
		self.statesInited[state] = true
	end
end

function LXSC.Datamodel:eval(expression)
	return self:run('return '..expression)
end

function LXSC.Datamodel:run(code)
	local func,err = self.cache[code]
	if not func then
		func,err = load(code, nil, 't', self.scope)
		if func then
			self.cache[code] = func
		else
			self.scxml:fireEvent("error.execution.syntax",err)
			return LXSC.Datamodel.EVALERROR
		end
	end
	if func then
		local ok,result = pcall(func)
		if not ok then
			self.scxml:fireEvent("error.execution.evaluation",result)
			return LXSC.Datamodel.EVALERROR
		else
			return result
		end
	end
end

-- Reserved for internal use; should not be used by user scripts
function LXSC.Datamodel:_setSystem(location,value)
	self.scope[location] = value
	if rawget(self.scxml,'onDataSet') then self.scxml.onDataSet(location,value) end
end

function LXSC.Datamodel:set(location,value)
	-- TODO: support foo.bar location dereferencing
	if location~=nil then
		if type(location)=='string' and string.sub(location,1,1)=='_' then
			self.scxml:fireEvent("error.execution.invalid-set","Cannot set system variables")
		else
			self.scope[location] = value
			if rawget(self.scxml,'onDataSet') then self.scxml.onDataSet(location,value) end
			return true
		end
	else
		self.scxml:fireEvent("error.execution.invalid-set","Location must not be nil")
	end
end

function LXSC.Datamodel:get(id)
	if id==nil or id=='' then
		return LXSC.Datamodel.INVALIDLOCATION
	else
		return self.scope[id]
	end
end

function LXSC.Datamodel:serialize(pretty)
	if pretty then
		return LXSC.serializeLua(self.scope,{sort=self.__sorter,indent='  '})
	else
		return LXSC.serializeLua(self.scope)
	end
end

function LXSC.Datamodel.__sorter(a,b)
	local ak,av,bk,bv     = a[1],a[2],b[1],b[2]
	local tak,tav,tbk,tbv = type(a[1]),type(a[2]),type(b[1]),type(b[2])
	a,b = ak,bk
	if tav=='function' then a='~~~'..ak end
	if tak=='function' then a='~~~~' end
	if tbv=='function' then b='~~~'..bk end
	if tbk=='function' then b='~~~~' end
	if tak=='string' and ak:find('_')==1 then a='~~'..ak end
	if tbk=='string' and bk:find('_')==1 then b='~~'..bk end
	if type(a)==type(b) then return a<b end
end

 -- unique identifiers for comparision
LXSC.Datamodel.EVALERROR = {}
LXSC.Datamodel.INVALIDLOCATION = {}










LXSC.Event={
	origintype="http://www.w3.org/TR/scxml/#SCXMLEventProcessor",
	type      ="platform",
	sendid    ="",
	origin    ="",
	invokeid  ="",	
}
local EventMeta; EventMeta = { __index=LXSC.Event, __tostring=function(e) return e:inspect() end }
setmetatable(LXSC.Event,{__call=function(_,name,data,fields)
	local e = {name=name,data=data,_tokens={}}
	setmetatable(e,EventMeta)
	for k,v in pairs(fields) do e[k] = v end
	for token in string.gmatch(name,'[^.*]+') do table.insert(e._tokens,token) end
	return e
end})



function LXSC.Event:triggersDescriptor(descriptor)
	if self.name==descriptor or descriptor=="*" then
		return true
	else
		local i=1
		for token in string.gmatch(descriptor,'[^.*]+') do
			if self._tokens[i]~=token then return false end
			i=i+1
		end
		return true
	end
	return false
end

function LXSC.Event:triggersTransition(t) return t:matchesEvent(self) end

function LXSC.Event:inspect(detailed)
	if detailed then
		return "<event>"..LXSC.serializeLua( self, {sort=self.__sorter, nokey={_tokens=1}} )
	else
		return string.format("<event '%s' type=%s>",self.name,self.type)
	end
end

function LXSC.Event.__sorter(a,b)
	local keyorder = {name='_____________',type='___',data='~~~~~~~~~~~~'}
	a = keyorder[a[1]] or a[1]
	b = keyorder[b[1]] or b[1]
	return a<b
end










local generic = {}
local genericMeta = {__index=generic }

function LXSC:_generic(kind,nsURI)
	return setmetatable({_kind=kind,_kids={},_nsURI=nsURI},genericMeta)
end

function generic:addChild(item)
	table.insert(self._kids,item)
end

function generic:attr(name,value)
	self[name] = value
end

setmetatable(LXSC,{__index=function() return LXSC._generic end})










LXSC.Exec = {}

function LXSC.Exec:log(scxml)
	local message = {self.label}
	if self.expr and self.expr~="" then
		local value = scxml:eval(self.expr)
		if value==LXSC.Datamodel.EVALERROR then return end
		table.insert(message,tostring(value))
	end
	print(table.concat(message,": "))
	return true
end

function LXSC.Exec:assign(scxml)
	-- TODO: support child executable content in place of expr
	if self.location=="" then
		scxml:fireEvent("error.execution.invalid-location","Unsupported <assign> location '"..tostring(self.location).."'")
	else
		local value = scxml:eval(self.expr)
		if value~=LXSC.Datamodel.EVALERROR then
			scxml:set( self.location, value )
			return true
		end
	end
end

function LXSC.Exec:raise(scxml)
	scxml:fireEvent(self.event,nil,{type='internal',origintype=''})
	return true
end

function LXSC.Exec:script(scxml)
	local result = scxml:run(self._text)
	return result ~= LXSC.Datamodel.EVALERROR
end

function LXSC.Exec:send(scxml)
	-- TODO: support type/typeexpr/target/targetexpr
	local type = self.type or self.typeexpr and scxml:eval(self.typeexpr)
	if type == LXSC.Datamodel.EVALERROR then return end

	local id = self.id
	if self.idlocation and not id then
		local loc = scxml:eval(self.idlocation)
		if loc == LXSC.Datamodel.EVALERROR then return end
		id = LXSC.uuid4()
		scxml:set( loc, id )
	end

	if not type then type = 'http://www.w3.org/TR/scxml/#SCXMLEventProcessor' end
	if type ~= 'http://www.w3.org/TR/scxml/#SCXMLEventProcessor' then
		scxml:fireEvent("error.execution.invalid-send-type","Unsupported <send> type '"..tostring(type).."'",{sendid=id})
		return
	end	

	local target = self.target or self.targetexpr and scxml:eval(self.targetexpr)
	if target == LXSC.Datamodel.EVALERROR then return end
	if target and target ~= '#_internal' and target ~= '#_scxml_' .. scxml:get('_sessionid') then
		scxml:fireEvent("error.execution.invalid-send-target","Unsupported <send> target '"..tostring(target).."'",{sendid=id})
		return
	end

	local name = self.event or scxml:eval(self.eventexpr)
	if name == LXSC.Datamodel.EVALERROR then return end
	local data
	if self.namelist then
		data = {}
		for name in string.gmatch(self.namelist,'[^%s]+') do data[name] = scxml:get(name) end
		if not next(data) then
			scxml:fireEvent("error.execution.invalid-send-namelist","<send> namelist must include one or more locations",{sendid=id})
			return
		end
	end
	for _,child in ipairs(self._kids) do
		if child._kind=='param' then
			if not data then data = {} end
			if not scxml:executeSingle(child,data) then return end
		elseif child._kind=='content' then
			if data then error("<send> may not have both <param> and <content> child elements.") end
			data = {}
			if not scxml:executeSingle(child,data) then return end
			data = data.content -- unwrap the content
		end
	end

	if self.delay or self.delayexpr then
		local delay = self.delay or scxml:eval(self.delayexpr)
		if delay == LXSC.Datamodel.EVALERROR then return end
		local delaySeconds, units = string.match(delay,'^(.-)(m?s)')
		delaySeconds = tonumber(delaySeconds)
		if units=="ms" then delaySeconds = delaySeconds/1000 end
		local delayedEvent = { expires=scxml:elapsed()+delaySeconds, name=name, data=data, sendid=id }
		local i=1
		for _,delayed2 in ipairs(scxml._delayedSend) do
			if delayed2.expires>delayedEvent.expires then break else i=i+1 end
		end
		table.insert(scxml._delayedSend,i,delayedEvent)
	else
		local fields = {type=target=='#_internal' and 'internal' or 'external'}
		if fields.type=='external' then
			fields.origin = '#_scxml_' .. scxml:get('_sessionid')
		else
			fields.origintype = ''
		end
		fields.sendid = self.id
		scxml:fireEvent(name,data,fields)
	end
	return true
end

function LXSC.Exec:param(scxml,context)
	if not context   then error("<param name='"..self.name.."' /> only supported as child of <send>") end
	if not self.name then error("<param> element missing 'name' attribute") end
	if not (self.location or self.expr) then error("<param> element requires either 'expr' or 'location' attribute") end
	local val
	if self.location then
		val = scxml:get(self.location)
		if val == LXSC.Datamodel.INVALIDLOCATION then return end
	elseif self.expr then
		val = scxml:eval(self.expr)
		if val == LXSC.Datamodel.EVALERROR then return end
	end
	context[self.name] = val
	return true
end

function LXSC.Exec:content(scxml,context)
	if not context then error("<content> only supported as child of <send> or <donedata>") end
	if self.expr and self._text then error("<content> element must have either 'expr' attribute or child content, but not both") end
	if not (self.expr or self._text) then error("<content> element requires either 'expr' attribute or child content") end
	local val = scxml:eval(self.expr or self._text)
	if val == LXSC.Datamodel.EVALERROR then return end
	context.content = val
	return true
end

function LXSC.Exec:cancel(scxml)
	local sendid = self.sendid or scxml:eval(self.sendidexpr)
	if sendid == LXSC.Datamodel.EVALERROR then return end
	scxml:cancelDelayedSend(sendid)
	return true
end

LXSC.Exec['if'] = function (self,scxml)
	local result = scxml:eval(self.cond)
	if result == LXSC.Datamodel.EVALERROR then return end
	if result then
		for _,child in ipairs(self._kids) do
			if child._kind=='else' or child._kind=='elseif' then
				break
			else
				if not scxml:executeSingle(child) then return end
			end
		end
	else
		local executeFlag = false
		for _,child in ipairs(self._kids) do
			if child._kind=='else' then
				if executeFlag then break else executeFlag = true end
			elseif child._kind=='elseif' then
				if executeFlag then
					break
				else
					result = scxml:eval(child.cond)
					if result == LXSC.Datamodel.EVALERROR then return end
					if result then executeFlag = true end
				end
			elseif executeFlag then
				if not scxml:executeSingle(child) then return end
			end
		end
	end
	return true
end

function LXSC.Exec:foreach(scxml)
	local array = scxml:get(self.array)
	if type(array) ~= 'table' then
		scxml:fireEvent('error.execution',"foreach array '"..self.array.."' is not a table")
	else
		local list = {}
		for i,v in ipairs(array) do list[i]=v end
		for i,v in ipairs(list) do
			if not scxml:set(self.item,v) then return end
			if self.index and not scxml:set(self.index,i) then return end
			for _,child in ipairs(self._kids) do
				if not scxml:executeSingle(child) then return end
			end
		end
		return true
	end
end

function LXSC.SCXML:processDelayedSends() -- automatically called by :step()
	local i,last=1,#self._delayedSend
	while i<=last do
		local delayedEvent = self._delayedSend[i]
		if delayedEvent.expires <= self:elapsed() then
			table.remove(self._delayedSend,i)
			self:fireEvent(delayedEvent.name,delayedEvent.data,{type='external'})
			last = last-1
		else
			i=i+1
		end
	end
end

function LXSC.SCXML:cancelDelayedSend(sendId)
	for i=#self._delayedSend,1,-1 do
		if self._delayedSend[i].sendid==sendId then table.remove(self._delayedSend,i) end
	end
end

-- ******************************************************************

function LXSC.SCXML:executeContent(parent)
	for _,executable in ipairs(parent._kids) do
		if not self:executeSingle(executable) then break end
	end
end

function LXSC.SCXML:executeSingle(item,...)
	local handler = LXSC.Exec[item._kind]
	if handler then
		return handler(item,self,...)
	else
		self:fireEvent('error.execution.unhandled',"unhandled executable type "..item._kind)
		return true -- Just because we didn't understand it doesn't mean we should stop processing executable
	end
end











LXSC.Script={}; LXSC.Script.__meta = {__index=LXSC.Script,}
function LXSC:script()
	local t = { _kind = 'script' }
	return setmetatable(t,self.Script.__meta)
end

function LXSC.Script:attr(name,value)
	if name=="src" then
		local scheme, hierarchy
		local colon = value:find(':')
		if colon then scheme,hierarchy = value:sub(1,colon-1), value:sub(colon+1) end
		if scheme=='file' then
			local f = assert(io.open(hierarchy,"r"))
			self._text = f:read("*all")
			f:close()
		else
			error("Cannot load <script src='"..value.."'>")
		end
	else
		print("Unexpected <script> attribute "..name.."='"..tostring(value).."'")
	end
end

function LXSC.Script:onFinishedParsing()
	if not self._text then
		error("<script> elements must have either a src attribute or text contents.")
	end
end










LXSC.OrderedSet = {_kind='OrderedSet'}; LXSC.OrderedSet.__meta = {__index=LXSC.OrderedSet}

setmetatable(LXSC.OrderedSet,{__call=function(o)
	return setmetatable({},o.__meta)
end})

function LXSC.OrderedSet:add(e)
	if not self[e] then
		local idx = #self+1
		self[idx] = e
		self[e] = idx
	end
end

function LXSC.OrderedSet:delete(e)
	local index = self[e]
	if index then
		table.remove(self,index)
		self[e] = nil
		for i,o in ipairs(self) do self[o]=i end -- Store new indexes
	end
end

function LXSC.OrderedSet:union(set2)
	local i=#self
	for _,e in ipairs(set2) do
		if not self[e] then
			i = i+1
			self[i] = e
			self[e] = i
		end
	end
end

function LXSC.OrderedSet:isMember(e)
	return self[e]
end

function LXSC.OrderedSet:some(f)
	for _,o in ipairs(self) do
		if f(o) then return true end
	end
end

function LXSC.OrderedSet:every(f)
	for _,v in ipairs(self) do
		if not f(v) then return false end
	end
	return true
end

function LXSC.OrderedSet:isEmpty()
	return not self[1]
end

function LXSC.OrderedSet:clear()
	for k,v in pairs(self) do self[k]=nil end
end

function LXSC.OrderedSet:toList()
	return LXSC.List(unpack(self))
end

function LXSC.OrderedSet:hasIntersection(set2)
	if #self<#set2 then
		for _,e in ipairs(self) do if set2[e] then return true end end
	else
		for _,e in ipairs(set2) do if self[e] then return true end end
	end
	return false
end

function LXSC.OrderedSet:inspect()
	local t = {}
	for i,v in ipairs(self) do t[i] = v.inspect and v:inspect() or tostring(v) end
	return t[1] and "{ "..table.concat(t,', ').." }" or '{}'
end

-- *******************************************************************

LXSC.List = {_kind='List'}; LXSC.List.__meta = {__index=LXSC.List}
setmetatable(LXSC.List,{__call=function(o,...)
	return setmetatable({...},o.__meta)
end})

function LXSC.List:head()
	return self[1]
end

function LXSC.List:tail()
	local l = LXSC.List(unpack(self))
	table.remove(l,1)
	return l
end

function LXSC.List:append(...)
	local len=#self
	for i,v in ipairs{...} do self[len+i] = v end
	return self
end

function LXSC.List:filter(f)
	local t={}
	local i=1
	for _,v in ipairs(self) do
		if f(v) then
			t[i]=v; i=i+1
		end
	end
	return LXSC.List(unpack(t))
end

LXSC.List.some    = LXSC.OrderedSet.some
LXSC.List.every   = LXSC.OrderedSet.every
LXSC.List.inspect = LXSC.OrderedSet.inspect

function LXSC.List:sort(f)
	table.sort(self,f)
	return self
end


-- *******************************************************************

LXSC.Queue = {_kind='Queue'}; LXSC.Queue.__meta = {__index=LXSC.Queue}
setmetatable(LXSC.Queue,{__call=function(o)
	return setmetatable({},o.__meta)
end})

function LXSC.Queue:enqueue(e)
	self[#self+1] = e
end

function LXSC.Queue:dequeue()
	return table.remove(self,1)
end

function LXSC.Queue:isEmpty()
	return not self[1]
end

LXSC.Queue.inspect = LXSC.OrderedSet.inspect










;(function(S)
S.MAX_ITERATIONS = 1000
local OrderedSet,Queue,List = LXSC.OrderedSet, LXSC.Queue, LXSC.List

-- ****************************************************************************

local function entryOrder(a,b)    return a._order < b._order end
local function exitOrder(a,b)     return b._order < a._order end
local function isDescendant(a,b)  return a:descendantOf(b)   end
local function isCancelEvent(e)   return e.name=='quit.lxsc' end
local function isFinalState(s)    return s._kind=='final'    end
local function isScxmlState(s)    return s._kind=='scxml'    end
local function isHistoryState(s)  return s._kind=='history'  end
local function isParallelState(s) return s._kind=='parallel' end
local function isCompoundState(s) return s.isCompound        end
local function isAtomicState(s)   return s.isAtomic          end
local function getChildStates(s)  return s.reals             end
local function findLCCA(first,rest) -- least common compound ancestor
	for _,anc in ipairs(first.ancestors) do
		if isCompoundState(anc) or isScxmlState(anc) then
			if rest:every(function(s) return isDescendant(s,anc) end) then
				return anc
			end
		end
	end
end

local emptyList = List()

local depth=0
local function logloglog(s)
	-- print(string.rep('   ',depth)..tostring(s))
end
local function startfunc(s) logloglog(s) depth=depth+1 end
local function closefunc(s) if s then logloglog(s) end depth=depth-1 end

-- ****************************************************************************

function S:interpret(options)
	self._delayedSend = { extraTime=0 }

	-- if not self:validate() then self:failWithError() end
	if not rawget(self,'_stateById') then self:expandScxmlSource() end
	self._configuration:clear()
	self._statesToInvoke = OrderedSet()
	self._internalQueue  = Queue()
	self._externalQueue  = Queue()
	self._historyValue   = {}

	self._data = LXSC.Datamodel(self,options and options.data)
	self._data:_setSystem('_sessionid',LXSC.uuid4())
	self._data:_setSystem('_name',self.name or LXSC.uuid4())
	self._data:_setSystem('_ioprocessors',{})
	if self.binding == "early" then self._data:initAll() end
	self.running = true
	self:executeGlobalScriptElement()
	self:enterStates(self.initial.transitions)
	self:mainEventLoop()
end

-- ******************************************************************************************************
-- ******************************************************************************************************
-- ******************************************************************************************************

function S:mainEventLoop()
	local anyTransition, enabledTransitions, macrostepDone, iterations
	while self.running do
		anyTransition = false -- (LXSC specific)
		iterations    = 0     -- (LXSC specific)
		macrostepDone = false

		-- Here we handle eventless transitions and transitions
		-- triggered by internal events until macrostep is complete
		while self.running and not macrostepDone and iterations<S.MAX_ITERATIONS do
			enabledTransitions = self:selectEventlessTransitions()
			if enabledTransitions:isEmpty() then
				if self._internalQueue:isEmpty() then
					macrostepDone = true
				else
					logloglog("-- Internal Queue: "..self._internalQueue:inspect())
					local internalEvent = self._internalQueue:dequeue()
					self._data:_setSystem('_event',internalEvent)
					enabledTransitions = self:selectTransitions(internalEvent)
				end
			end
			if not enabledTransitions:isEmpty() then
				anyTransition = true
				self:microstep(enabledTransitions)
			end
			iterations = iterations + 1
		end

		if iterations>=S.MAX_ITERATIONS then print(string.format("Warning: stopped unstable system after %d internal iterations",S.MAX_ITERATIONS)) end

		-- Either we're in a final state, and we break out of the loop???
		if not self.running then break end
		-- ???or we've completed a macrostep, so we start a new macrostep by waiting for an external event

		-- Here we invoke whatever needs to be invoked. The implementation of 'invoke' is platform-specific
		for _,state in ipairs(self._statesToInvoke) do for _,inv in ipairs(state._invokes) do self:invoke(inv) end end
		self._statesToInvoke:clear()

		-- Invoking may have raised internal error events; if so, we skip and iterate to handle them
		if self._internalQueue:isEmpty() then
			logloglog("-- External Queue: "..self._externalQueue:inspect())
			local externalEvent = self._externalQueue:dequeue()
			if externalEvent then -- (LXSC specific) The queue might be empty.
				if isCancelEvent(externalEvent) then
					self.running = false
				else
					self._data:_setSystem('_event',externalEvent)
						for _,state in ipairs(self._configuration) do
							for _,inv in ipairs(state._invokes) do
								if inv.invokeid == externalEvent.invokeid then self:applyFinalize(inv, externalEvent) end
								if inv.autoforward then self:send(inv.id, externalEvent) end
							end
						end
						enabledTransitions = self:selectTransitions(externalEvent)
						if not enabledTransitions:isEmpty() then
							anyTransition = true
							self:microstep(enabledTransitions)
						end
					end
				end

			-- (LXSC specific) we stop iterating as soon as no transitions occur
			if not anyTransition then break end
		end
	end

	-- We re-check if we're running here because LXSC uses step-based processing;
	-- we may have exited the 'running' loop if there were no more events to process.
	if not self.running then self:exitInterpreter() end
end

-- ******************************************************************************************************
-- ******************************************************************************************************
-- ******************************************************************************************************

function S:executeGlobalScriptElement()
	if rawget(self,'_script') then self:executeSingle(self._script) end
end

function S:exitInterpreter()
	local statesToExit = self._configuration:toList():sort(exitOrder)
	for _,s in ipairs(statesToExit) do
		for _,content in ipairs(s._onexits) do self:executeContent(content) end
		for _,inv	    in ipairs(s._invokes) do self:cancelInvoke(inv)       end

		-- (LXSC specific) We do not delete the configuration on exit so that it may be examined later.
		-- self._configuration:delete(s)

		if isFinalState(s) and isScxmlState(s.parent) then
			self:returnDoneEvent(self:donedata(s))
		end
	end
end

function S:selectEventlessTransitions()
	startfunc('selectEventlessTransitions()')
	local enabledTransitions = OrderedSet()
	local atomicStates = self._configuration:toList():filter(isAtomicState):sort(entryOrder)
	for _,state in ipairs(atomicStates) do
		self:addEventlessTransition(state,enabledTransitions)
	end
	enabledTransitions = self:removeConflictingTransitions(enabledTransitions)
	closefunc('-- selectEventlessTransitions result: '..enabledTransitions:inspect())
	return enabledTransitions
end
-- (LXSC specific) we use this function since Lua cannot break out of a nested loop
function S:addEventlessTransition(state,enabledTransitions)
	for _,s in ipairs(state.selfAndAncestors) do
		for _,t in ipairs(s._eventlessTransitions) do
			if t:conditionMatched(self._data) then
				enabledTransitions:add(t)
				return
			end
		end
	end
end

function S:selectTransitions(event)
	startfunc('selectTransitions( '..event:inspect()..' )')
	local enabledTransitions = OrderedSet()
	local atomicStates = self._configuration:toList():filter(isAtomicState):sort(entryOrder)
	for _,state in ipairs(atomicStates) do
		self:addTransitionForEvent(state,event,enabledTransitions)
	end
	enabledTransitions = self:removeConflictingTransitions(enabledTransitions)
	closefunc('-- selectTransitions result: '..enabledTransitions:inspect())
	return enabledTransitions
end
-- (LXSC specific) we use this function since Lua cannot break out of a nested loop
function S:addTransitionForEvent(state,event,enabledTransitions)
	for _,s in ipairs(state.selfAndAncestors) do
		for _,t in ipairs(s._eventedTransitions) do
			if t:matchesEvent(event) and t:conditionMatched(self._data) then
				enabledTransitions:add(t)
				return
			end
		end
	end
end

function S:removeConflictingTransitions(enabledTransitions)
	startfunc('removeConflictingTransitions( enabledTransitions:'..enabledTransitions:inspect()..' )')
	local filteredTransitions = OrderedSet()
	for _,t1 in ipairs(enabledTransitions) do
		local t1Preempted = false
		local transitionsToRemove = OrderedSet()
		for _,t2 in ipairs(filteredTransitions) do
			if self:computeExitSet(List(t1)):hasIntersection(self:computeExitSet(List(t2))) then
				if isDescendant(t1.source,t2.source) then
					transitionsToRemove:add(t2)
				else
					t1Preempted = true
					break
				end
			end
		end

		if not t1Preempted then
			for _,t3 in ipairs(transitionsToRemove) do
				filteredTransitions:delete(t3)
			end
			filteredTransitions:add(t1)
		end
	end

	closefunc('-- removeConflictingTransitions result: '..filteredTransitions:inspect())
	return filteredTransitions
end

function S:microstep(enabledTransitions)
	startfunc('microstep( enabledTransitions:'..enabledTransitions:inspect()..' )')

	self:exitStates(enabledTransitions)
	self:executeTransitionContent(enabledTransitions)
	self:enterStates(enabledTransitions)

	if rawget(self,'onEnteredAll') then self.onEnteredAll() end

	closefunc()
end

function S:exitStates(enabledTransitions)
	startfunc('exitStates( enabledTransitions:'..enabledTransitions:inspect()..' )')

	local statesToExit = self:computeExitSet(enabledTransitions)
	for _,s in ipairs(statesToExit) do self._statesToInvoke:delete(s) end
	statesToExit = statesToExit:toList():sort(exitOrder)

	-- Record history for states being exited
	for _,s in ipairs(statesToExit) do
		for _,h in ipairs(s.states) do
			if h._kind=='history' then
				self._historyValue[h.id] = self._configuration:toList():filter(function(s0)
					if h.type=='deep' then
						return isAtomicState(s0) and isDescendant(s0,s)
					else
						return s0.parent==s
					end
				end)
			end
		end
	end

	-- Exit the states
	for _,s in ipairs(statesToExit) do
		if rawget(self,'onBeforeExit') then self.onBeforeExit(s.id,s._kind,s.isAtomic) end
		for _,content in ipairs(s._onexits) do
			self:executeContent(content)
		end
		for _,inv in ipairs(s._invokes) do self:cancelInvoke(inv) end
		self._configuration:delete(s)
		logloglog(string.format("-- removed %s from the configuration; config is now {%s}",s:inspect(),table.concat(self:activeStateIds(),', ')))
	end

	closefunc()
end

function S:computeExitSet(transitions)
	startfunc('computeExitSet( transitions:'..transitions:inspect()..' )')
	local statesToExit = OrderedSet()
	for _,t in ipairs(transitions) do
		if t.targets then
			local domain = self:getTransitionDomain(t)
			for _,s in ipairs(self._configuration) do
				if isDescendant(s,domain) then
					statesToExit:add(s)
				end
			end
		end
	end
	closefunc('-- computeExitSet result '..statesToExit:inspect())
	return statesToExit
end

function S:executeTransitionContent(enabledTransitions)
	startfunc('executeTransitionContent( enabledTransitions:'..enabledTransitions:inspect()..' )')
	for _,t in ipairs(enabledTransitions) do
		if rawget(self,'onTransition') then self.onTransition(t) end
		for _,executable in ipairs(t._exec) do
			if not self:executeSingle(executable) then break end
		end
	end
	closefunc()
end

function S:enterStates(enabledTransitions)
	startfunc('enterStates( enabledTransitions:'..enabledTransitions:inspect()..' )')

	local statesToEnter         = OrderedSet()
	local statesForDefaultEntry = OrderedSet()
	local defaultHistoryContent = {}           -- temporary table for default content in history states
	self:computeEntrySet(enabledTransitions,statesToEnter,statesForDefaultEntry,defaultHistoryContent)

	for _,s in ipairs(statesToEnter:toList():sort(entryOrder)) do
		self._configuration:add(s)
		logloglog(string.format("-- added %s '%s' to the configuration; config is now <%s>",s._kind,s.id,table.concat(self:activeStateIds(),', ')))
		if isScxmlState(s) then error("Added SCXML to configuration.") end
		self._statesToInvoke:add(s)

		if self.binding=="late" then
			-- The LXSC datamodel ensures this happens only once per state
			self._data:initState(s)
		end

		for _,content in ipairs(s._onentrys) do
			self:executeContent(content)
		end
		if rawget(self,'onAfterEnter') then self.onAfterEnter(s.id,s._kind,s.isAtomic) end

		if statesForDefaultEntry:isMember(s) then
			for _,t in ipairs(s.initial.transitions) do
				for _,executable in ipairs(t._exec) do
					if not self:executeSingle(executable) then break end
				end
			end
		end

		if defaultHistoryContent[s.id] then
			logloglog("-- executing defaultHistoryContent for "..s.id)
			for _,executable in ipairs(defaultHistoryContent[s.id]) do
				if not self:executeSingle(executable) then break end
			end
		end

		if isFinalState(s) then
			local parent = s.parent
			if isScxmlState(parent) then
				self.running = false
			else
				local grandparent = parent.parent
				self:fireEvent( "done.state."..parent.id, self:donedata(s), {type='internal'} )
				if isParallelState(grandparent) then
					local allAreInFinal = true
					for _,child in ipairs(grandparent.reals) do
						if not self:isInFinalState(child) then
							allAreInFinal = false
							break
						end
					end
					if allAreInFinal then
						self:fireEvent( "done.state."..grandparent.id, nil, {type='internal'} )
					end
				end
			end
		end

	end

	closefunc()
end

function S:computeEntrySet(transitions,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
	startfunc('computeEntrySet( transitions:'..transitions:inspect()..', ... )')

	for _,t in ipairs(transitions) do
		if t.targets then
			for _,s in ipairs(t.targets) do
				self:addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
			end
		end
		-- logloglog('-- after adding descendants statesToEnter is: '..statesToEnter:inspect())

		local ancestor = self:getTransitionDomain(t)
		for _,s in ipairs(self:getEffectiveTargetStates(t)) do
			self:addAncestorStatesToEnter(s,ancestor,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
		end
	end
	logloglog('-- computeEntrySet result statesToEnter: '..statesToEnter:inspect())
	logloglog('-- computeEntrySet result statesForDefaultEntry: '..statesForDefaultEntry:inspect())
	closefunc()
end

function S:addDescendantStatesToEnter(state,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
	startfunc("addDescendantStatesToEnter( state:"..state:inspect()..", ... )")
	if isHistoryState(state) then

		if self._historyValue[state.id] then
			for _,s in ipairs(self._historyValue[state.id]) do
				self:addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
				self:addAncestorStatesToEnter(s,state.parent,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
			end
		else
			defaultHistoryContent[state.parent.id] = state.transitions[1]._exec
			logloglog("-- defaultHistoryContent['"..state.parent.id.."'] = "..(#state.transitions[1]._exec).." executables")
			for _,t in ipairs(state.transitions) do
				if t.targets then
					for _,s in ipairs(t.targets) do
						self:addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
						self:addAncestorStatesToEnter(s,state.parent,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
					end
				end
			end
		end

	else

		statesToEnter:add(state)
		logloglog("statesToEnter:add( "..state:inspect().." )")

		if isCompoundState(state) then
			statesForDefaultEntry:add(state)
			for _,t in ipairs(state.initial.transitions) do
				for _,s in ipairs(t.targets) do
					self:addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
					self:addAncestorStatesToEnter(s,state,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
				end
			end
		elseif isParallelState(state) then
			for _,child in ipairs(getChildStates(state)) do
				if not statesToEnter:some(function(s) return isDescendant(s,child) end) then
					self:addDescendantStatesToEnter(child,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
				end
			end
		end

	end

	closefunc()
end

function S:addAncestorStatesToEnter(state,ancestor,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
	startfunc("addAncestorStatesToEnter( state:"..state:inspect()..", ancestor:"..ancestor:inspect()..", ... )")

	for anc in state:ancestorsUntil(ancestor) do
		statesToEnter:add(anc)
		logloglog("statesToEnter:add( "..anc:inspect().." )")
		if isParallelState(anc) then
			for _,child in ipairs(getChildStates(anc)) do
				if not statesToEnter:some(function(s) return isDescendant(s,child) end) then
					self:addDescendantStatesToEnter(child,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
				end
			end
		end
	end

	closefunc()
end

function S:isInFinalState(s)
	if isCompoundState(s) then
		return getChildStates(s):some(function(s) return isFinalState(s) and self._configuration:isMember(s)	end)
	elseif isParallelState(s) then
		return getChildStates(s):every(function(s) self:isInFinalState(s) end)
	else
		return false
	end
end

function S:getTransitionDomain(t)
	startfunc('getTransitionDomain( t:'..t:inspect()..' )' )
	local result
	local tstates = self:getEffectiveTargetStates(t)
	if not tstates[1] then
		result = nil
	elseif t.type=='internal' and isCompoundState(t.source) and tstates:every(function(s) return isDescendant(s,t.source) end) then
		result = t.source
	else
		result = findLCCA(t.source,t.targets or emptyList)
	end
	closefunc('-- getTransitionDomain result: '..tostring(result and result.id))
	return result
end

function S:getEffectiveTargetStates(transition)
	startfunc('getEffectiveTargetStates( transition:'..transition:inspect()..' )')
	local targets = OrderedSet()
	if transition.targets then
		for _,s in ipairs(transition.targets) do
			if isHistoryState(s) then
				if self._historyValue[s.id] then
					targets:union(self._historyValue[s.id])
				else
					-- History states can only have one transition, so we hard-code that here.
					targets:union(self:getEffectiveTargetStates(s.transitions[1]))
				end
			else
				targets:add(s)
			end
		end
	end
	closefunc('-- getEffectiveTargetStates result: '..targets:inspect())
	return targets
end

function S:expandScxmlSource()
	self:convertInitials()
	self._stateById = {}
	for _,s in ipairs(self.states) do s:cacheReference(self._stateById) end
	self:resolveReferences(self._stateById)
end

function S:returnDoneEvent(donedata)
	-- TODO: implement
end

function S:invoke(invoke)
	-- TODO: implement <invoke>
	error("Invoke not supported.")
end

function S:donedata(state)
	local c = state._donedatas[1]
	if c then
		if c._kind=='content' then
			local wrapper = {}
			self:executeSingle(c,wrapper)
			return wrapper.content
		else
			local map = {}
			for _,p in ipairs(state._donedatas) do
				local val = p.location and self._data:get(p.location) or p.expr and self._data:eval(p.expr)
				if val == LXSC.Datamodel.INVALIDLOCATION then
					self:fireEvent("error.execution.invalid-param-value","There was an error determining the value for a <param> inside a <donedata>")
				elseif val ~= LXSC.Datamodel.EVALERROR then
					if p.name==nil or p.name=="" then
						self:fireEvent("error.execution.invalid-param-name","Unsupported <param> name '"..tostring(p.name).."'")
					else
						map[p.name] = val
					end
				end
			end
			return next(map) and map
		end
	end
end

function S:fireEvent(name,data,eventValues)
	eventValues = eventValues or {}
	eventValues.type = eventValues.type or 'platform'
	local event = LXSC.Event(name,data,eventValues)
	logloglog(string.format("-- queued %s event '%s'",event.type,event.name))
	if rawget(self,'onEventFired') then self.onEventFired(event) end
	self[eventValues.type=='external' and "_externalQueue" or "_internalQueue"]:enqueue(event)
	return event
end

-- Sensible aliases
S.start   = S.interpret
S.restart = S.interpret

function S:step()
	self:processDelayedSends()
	self:mainEventLoop()
end

end)(LXSC.SCXML)










local SLAXML = (function()
--[=====================================================================[
v0.8 Copyright ?? 2013-2018 Gavin Kistner <!@phrogz.net>; MIT Licensed
See http://github.com/Phrogz/SLAXML for details.
--]=====================================================================]
local SLAXML = {
	VERSION = "0.8",
	_call = {
		pi = function(target,content)
			print(string.format("<?%s %s?>",target,content))
		end,
		comment = function(content)
			print(string.format("<!-- %s -->",content))
		end,
		startElement = function(name,nsURI,nsPrefix)
			                 io.write("<")
			if nsPrefix then io.write(nsPrefix,":") end
			                 io.write(name)
			if nsURI    then io.write(" (ns='",nsURI,"')") end
			                 print(">")
		end,
		attribute = function(name,value,nsURI,nsPrefix)
			                 io.write('  ')
			if nsPrefix then io.write(nsPrefix,":") end
			                 io.write(name,'=',string.format('%q',value))
			if nsURI    then io.write(" (ns='",nsURI,"')") end
			                 io.write("\n")
		end,
		text = function(text,cdata)
			print(string.format("  %s: %q",cdata and 'cdata' or 'text',text))
		end,
		closeElement = function(name,nsURI,nsPrefix)
			                 io.write("</")
			if nsPrefix then io.write(nsPrefix,":") end
			                 print(name..">")
		end,
	}
}

function SLAXML:parser(callbacks)
	return { _call=callbacks or self._call, parse=SLAXML.parse }
end

function SLAXML:parse(xml,options)
	if not options then options = { stripWhitespace=false } end

	-- Cache references for maximum speed
	local find, sub, gsub, char, push, pop, concat = string.find, string.sub, string.gsub, string.char, table.insert, table.remove, table.concat
	local first, last, match1, match2, match3, pos2, nsURI
	local unpack = unpack or unpack
	local pos = 1
	local state = "text"
	local textStart = 1
	local currentElement={}
	local currentAttributes={}
	local currentAttributeCt -- manually track length since the table is re-used
	local nsStack = {}
	local anyElement = false

	local utf8markers = { {0x7FF,192}, {0xFFFF,224}, {0x1FFFFF,240} }
	local function utf8(decimal) -- convert unicode code point to utf-8 encoded character string
		if decimal<128 then return char(decimal) end
		local charbytes = {}
		for bytes,vals in ipairs(utf8markers) do
			if decimal<=vals[1] then
				for b=bytes+1,2,-1 do
					local mod = decimal%64
					decimal = (decimal-mod)/64
					charbytes[b] = char(128+mod)
				end
				charbytes[1] = char(vals[2]+decimal)
				return concat(charbytes)
			end
		end
	end
	local entityMap  = { ["lt"]="<", ["gt"]=">", ["amp"]="&", ["quot"]='"', ["apos"]="'" }
	local entitySwap = function(orig,n,s) return entityMap[s] or n=="#" and utf8(tonumber('0'..s)) or orig end
	local function unescape(str) return gsub( str, '(&(#?)([%d%a]+);)', entitySwap ) end

	local function finishText()
		if first>textStart and self._call.text then
			local text = sub(xml,textStart,first-1)
			if options.stripWhitespace then
				text = gsub(text,'^%s+','')
				text = gsub(text,'%s+$','')
				if #text==0 then text=nil end
			end
			if text then self._call.text(unescape(text),false) end
		end
	end

	local function findPI()
		first, last, match1, match2 = find( xml, '^<%?([:%a_][:%w_.-]*) ?(.-)%?>', pos )
		if first then
			finishText()
			if self._call.pi then self._call.pi(match1,match2) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function findComment()
		first, last, match1 = find( xml, '^<!%-%-(.-)%-%->', pos )
		if first then
			finishText()
			if self._call.comment then self._call.comment(match1) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function nsForPrefix(prefix)
		if prefix=='xml' then return 'http://www.w3.org/XML/1998/namespace' end -- http://www.w3.org/TR/xml-names/#ns-decl
		for i=#nsStack,1,-1 do if nsStack[i][prefix] then return nsStack[i][prefix] end end
		error(("Cannot find namespace for prefix %s"):format(prefix))
	end

	local function startElement()
		anyElement = true
		first, last, match1 = find( xml, '^<([%a_][%w_.-]*)', pos )
		if first then
			currentElement[2] = nil -- reset the nsURI, since this table is re-used
			currentElement[3] = nil -- reset the nsPrefix, since this table is re-used
			finishText()
			pos = last+1
			first,last,match2 = find(xml, '^:([%a_][%w_.-]*)', pos )
			if first then
				currentElement[1] = match2
				currentElement[3] = match1 -- Save the prefix for later resolution
				match1 = match2
				pos = last+1
			else
				currentElement[1] = match1
				for i=#nsStack,1,-1 do if nsStack[i]['!'] then currentElement[2] = nsStack[i]['!']; break end end
			end
			currentAttributeCt = 0
			push(nsStack,{})
			return true
		end
	end

	local function findAttribute()
		first, last, match1 = find( xml, '^%s+([:%a_][:%w_.-]*)%s*=%s*', pos )
		if first then
			pos2 = last+1
			first, last, match2 = find( xml, '^"([^<"]*)"', pos2 ) -- FIXME: disallow non-entity ampersands
			if first then
				pos = last+1
				match2 = unescape(match2)
			else
				first, last, match2 = find( xml, "^'([^<']*)'", pos2 ) -- FIXME: disallow non-entity ampersands
				if first then
					pos = last+1
					match2 = unescape(match2)
				end
			end
		end
		if match1 and match2 then
			local currentAttribute = {match1,match2}
			local prefix,name = string.match(match1,'^([^:]+):([^:]+)$')
			if prefix then
				if prefix=='xmlns' then
					nsStack[#nsStack][name] = match2
				else
					currentAttribute[1] = name
					currentAttribute[4] = prefix
				end
			else
				if match1=='xmlns' then
					nsStack[#nsStack]['!'] = match2
					currentElement[2]      = match2
				end
			end
			currentAttributeCt = currentAttributeCt + 1
			currentAttributes[currentAttributeCt] = currentAttribute
			return true
		end
	end

	local function findCDATA()
		first, last, match1 = find( xml, '^<!%[CDATA%[(.-)%]%]>', pos )
		if first then
			finishText()
			if self._call.text then self._call.text(match1,true) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function closeElement()
		first, last, match1 = find( xml, '^%s*(/?)>', pos )
		if first then
			state = "text"
			pos = last+1
			textStart = pos

			-- Resolve namespace prefixes AFTER all new/redefined prefixes have been parsed
			if currentElement[3] then currentElement[2] = nsForPrefix(currentElement[3])    end
			if self._call.startElement then self._call.startElement(unpack(currentElement)) end
			if self._call.attribute then
				for i=1,currentAttributeCt do
					if currentAttributes[i][4] then currentAttributes[i][3] = nsForPrefix(currentAttributes[i][4]) end
					self._call.attribute(unpack(currentAttributes[i]))
				end
			end

			if match1=="/" then
				pop(nsStack)
				if self._call.closeElement then self._call.closeElement(unpack(currentElement)) end
			end
			return true
		end
	end

	local function findElementClose()
		first, last, match1, match2 = find( xml, '^</([%a_][%w_.-]*)%s*>', pos )
		if first then
			nsURI = nil
			for i=#nsStack,1,-1 do if nsStack[i]['!'] then nsURI = nsStack[i]['!']; break end end
		else
			first, last, match2, match1 = find( xml, '^</([%a_][%w_.-]*):([%a_][%w_.-]*)%s*>', pos )
			if first then nsURI = nsForPrefix(match2) end
		end
		if first then
			finishText()
			if self._call.closeElement then self._call.closeElement(match1,nsURI) end
			pos = last+1
			textStart = pos
			pop(nsStack)
			return true
		end
	end

	while pos<#xml do
		if state=="text" then
			if not (findPI() or findComment() or findCDATA() or findElementClose()) then
				if startElement() then
					state = "attributes"
				else
					first, last = find( xml, '^[^<]+', pos )
					pos = (first and last or pos) + 1
				end
			end
		elseif state=="attributes" then
			if not findAttribute() then
				if not closeElement() then
					error("Was in an element and couldn't find attributes or the close.")
				end
			end
		end
	end

	if not anyElement then error("Parsing did not discover any elements") end
	if #nsStack > 0 then error("Parsing ended with unclosed elements") end
end

return SLAXML
end)()
function LXSC:parse(scxml)
	local push, pop = table.insert, table.remove
	local i, stack = 1, {}
	local current, root
	local stateKinds = LXSC.State.stateKinds
	local scxmlNS    = LXSC.scxmlNS
	local parser = SLAXML:parser{
		startElement = function(name,nsURI)
			local item
			if nsURI == scxmlNS then
				if stateKinds[name] then
					item = LXSC:state(name)
				else
					item = LXSC[name](LXSC,name,nsURI)
				end
			else
				item = LXSC:_generic(name,nsURI)
			end
			item._order = i; i=i+1
			if current then current:addChild(item) end
			current = item
			if not root then root = current end
			push(stack,item)
		end,
		attribute = function(name,value)
			current:attr(name,value)
		end,
		closeElement = function(name,nsURI)
			if current._kind ~= name then
				error(string.format("I was working with a '%s' element but got a close notification for '%s'",current._kind,name))
			end
			if name=="transition" and nsURI==scxmlNS then
				push( current.source[rawget(current,'events') and '_eventedTransitions' or '_eventlessTransitions'], current )
			end
			if rawget(current,'onFinishedParsing') then print(current.onFinishedParsing) current:onFinishedParsing() end
			pop(stack)
			current = stack[#stack] or current
		end,
		text = function(text)
			current._text = text
		end
	}
	parser:parse(scxml,{stripWhitespace=true})
	return root
end










local function serialize(v,opts)
	if not opts then opts = {} end
	if not opts.notype then opts.notype = {} end
	if not opts.nokey  then opts.nokey  = {} end
	if not opts.lv     then opts.lv=0        end
	if opts.sort and type(opts.sort)~='function' then opts.sort = function(a,b) if type(a[1])==type(b[1]) then return a[1]<b[1] end end end
	local t = type(v)
	if t=='string' then
		return string.format('%q',v)
	elseif t=='number' or t=='boolean' then
		return tostring(v)
	elseif t=='table' then
		local vals = {}
		local function serializeKV(k,v)
			local tk,tv = type(k),type(v)
			if not (opts.notype[tk] or opts.notype[tv] or opts.nokey[k]) then
				local indent=""
				if opts.indent then
					opts.lv = opts.lv + 1
					indent = opts.indent:rep(opts.lv)
				end
				if tk=='string' and string.find(k,'^[%a_][%a%d_]*$') then
					table.insert(vals,indent..k..'='..serialize(v,opts))
				else
					table.insert(vals,indent..'['..serialize(k,opts)..']='..serialize(v,opts))
				end
				if opts.indent then opts.lv = opts.lv-1 end
			end
		end
		if opts.sort then
			local numberKeys = {}
			local otherKeys  = {}
			for k,v in pairs(v) do
				if type(k)=='number' then
					table.insert(numberKeys,k)
				else
					table.insert(otherKeys,{k,v})
				end
			end
			table.sort(numberKeys)
			table.sort(otherKeys,opts.sort)
			for _,n in ipairs(numberKeys) do serializeKV(n,v[n])    end
			for _,o in ipairs(otherKeys)  do serializeKV(o[1],o[2]) end
		else
			for k,v in pairs(v) do serializeKV(k,v) end
		end
		if opts.indent then
			return #vals==0 and '{}' or '{\n'..table.concat(vals,',\n')..'\n'..opts.indent:rep(opts.lv)..'}'
		else
			return '{'..table.concat(vals,', ')..'}'
		end
	elseif t=='function' then
		return 'nil --[[ '..tostring(v)..' ]]'
	else
		error("Cannot serialize "..tostring(t))
	end
end

local function deserialize(str)
	local f,err = loadstring("return "..str)
	if not f then error(string.format('Error parsing %q: %s',str,err)) end
	local successFlag,resultOrError = pcall(f)
	if successFlag then
		return resultOrError
	else
		error(string.format("Error evaluating %q: %s",str,resultOrError))
	end
end

LXSC.serializeLua   = serialize
LXSC.deserializeLua = deserialize




















return LXSC
