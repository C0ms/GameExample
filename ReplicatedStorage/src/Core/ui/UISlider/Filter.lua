-- @ScriptType: ModuleScript
--!strict
--[[
	Author - RobloxJrTrainer
	
	'Filter' class for elegant and powerful configuration validation.
	Provides a declarative schema-based approach to validate complex table structures.
	
	V1.0.0 (Current)
]]

-- SERVICES --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- TYPES --

export type FilterInternals = {
	schemas: {[string]: Schema},
	errorCollector: {string}?
}

export type Filter = {
	DefineSchema: (self: Filter, name: string, schema: Schema) -> Filter,
	Validate: (self: Filter, config: any, schemaOrName: Schema | string) -> (boolean, any),
	ValidateStrict: (self: Filter, config: any, schemaOrName: Schema | string) -> any,
	GetErrors: (self: Filter) -> {string}?,
	Destroy: (self: Filter) -> ()
}

export type Schema = {
	[string]: FieldBuilder | FieldValidator | Schema
}

export type FieldValidator = {
	type: string | {string},
	optional: boolean?,
	default: any?,
	validator: ((any) -> boolean)?,
	transform: ((any) -> any)?,
	min: number?,
	max: number?,
	pattern: string?,
	enum: {any}?,
	arrayOf: FieldValidator?,
	mapOf: {key: FieldValidator?, value: FieldValidator?}?,
	description: string?
}

export type FieldBuilder = FieldValidator & {
	Required: (self: FieldBuilder) -> FieldBuilder,
	Optional: (self: FieldBuilder, defaultValue: any) -> FieldBuilder,
	Min: (self: FieldBuilder, min: number) -> FieldBuilder,
	Max: (self: FieldBuilder, max: number) -> FieldBuilder,
	Pattern: (self: FieldBuilder, pattern: string) -> FieldBuilder,
	Enum: (self: FieldBuilder, values: {any}) -> FieldBuilder,
	Transform: (self: FieldBuilder, transform: (any) -> any) -> FieldBuilder,
	Validator: (self: FieldBuilder, validatorFunc: (any) -> boolean, description: string?) -> FieldBuilder,
	ArrayOf: (self: FieldBuilder, itemValidator: FieldBuilder | FieldValidator) -> FieldBuilder,
	MapOf: (self: FieldBuilder, keyValidator: (FieldBuilder | FieldValidator)?, valueValidator: FieldBuilder | FieldValidator) -> FieldBuilder,
	Default: (self: FieldBuilder, value: any) -> FieldBuilder,
	Description: (self: FieldBuilder, desc: string) -> FieldBuilder
}

export type ValidationResult = {
	success: boolean,
	value: any,
	errors: {string}
}

-- VARIABLES --
local Filter = {}
local FilterMt = {
	__newindex = function(t, k, v)
		error(`Failed to set: '{k}' to '{v}'. 'Filter' cannot be modified!`)
	end,
}
FilterMt.__index = FilterMt

local privateData: {[Filter]: FilterInternals} = {}

-- CONSTANTS --
local PRIMITIVE_TYPES = {
	"string", "number", "boolean", "table", "function", 
	"thread", "userdata", "nil", "Instance", "Vector3", 
	"CFrame", "Color3", "BrickColor", "UDim2", "Ray"
}

local TYPE_SHORTCUTS = {
	str = "string",
	num = "number",
	bool = "boolean",
	func = "function",
	int = "integer",
	uint = "unsigned",
	array = "array",
	dict = "dictionary",
	map = "dictionary"
}

-- PRIVATE FUNCTIONS --

local function isArray(t: any): boolean
	if type(t) ~= "table" then return false end
	-- Empty tables are considered neither arrays nor dictionaries
	-- They will be handled separately in validation logic
	local count = 0
	local hasNumericKeys = false
	local hasNonNumericKeys = false

	for key in pairs(t) do
		count += 1
		if type(key) == "number" and key > 0 and key == math.floor(key) then
			hasNumericKeys = true
		else
			hasNonNumericKeys = true
		end
	end
	-- Empty table not classified as array or dictionary here
	if count == 0 then
		return false
	end
	-- If it has non numeric keys it's definitely not an array
	if hasNonNumericKeys then
		return false
	end
	-- Check if numeric keys are sequential starting from 1
	if hasNumericKeys then
		for i = 1, count do
			if t[i] == nil then
				return false
			end
		end
		return true
	end

	return false
end

local function validateType(value: any, expectedType: string | {string}): boolean
	local valueType = typeof(value)

	-- Handle type shortcuts
	if type(expectedType) == "string" then
		expectedType = TYPE_SHORTCUTS[expectedType] or expectedType

		-- Special type handlers
		if expectedType == "integer" then
			return valueType == "number" and value == math.floor(value)
		elseif expectedType == "unsigned" then
			return valueType == "number" and value >= 0 and value == math.floor(value)
		elseif expectedType == "array" then
			return isArray(value)
		elseif expectedType == "dictionary" then
			-- A dictionary must be a table that is not an array
			-- Empty tables are valid dictionaries
			return valueType == "table" and not isArray(value)
		else
			return valueType == expectedType
		end
	else
		-- Multiple accepted types
		for _, acceptedType in ipairs(expectedType) do
			if validateType(value, acceptedType) then
				return true
			end
		end
		return false
	end
end

local function validateField(value: any, validator: FieldValidator, path: string, errors: {string}): (boolean, any)
	-- Handle nil values
	if value == nil then
		if validator.optional then
			return true, validator.default
		else
			table.insert(errors, `{path}: Required field is missing`)
			return false, nil
		end
	end
	-- Handle empty tables for dictionary/array types that are required
	if type(value) == "table" then
		local isEmpty = next(value) == nil
		if isEmpty and not validator.optional then
			-- Check if this is supposed to be a dictionary or array type
			local expectedType = validator.type
			if type(expectedType) == "string" then
				expectedType = TYPE_SHORTCUTS[expectedType] or expectedType
				if expectedType == "dictionary" or expectedType == "array" or expectedType == "table" then
					-- Empty table for required field should be treated as missing
					table.insert(errors, `{path}: Required field cannot be empty`)
					return false, nil
				end
			elseif type(expectedType) == "table" then
				-- Check if any of the expected types are dictionary/array/table
				for _, eType in ipairs(expectedType) do
					eType = TYPE_SHORTCUTS[eType] or eType
					if eType == "dictionary" or eType == "array" or eType == "table" then
						table.insert(errors, `{path}: Required field cannot be empty`)
						return false, nil
					end
				end
			end
		elseif isEmpty and validator.optional then
			-- Return default value for empty optional fields
			return true, validator.default
		end
	end
	-- Type validation
	if not validateType(value, validator.type) then
		local typeStr = type(validator.type) == "table" 
			and table.concat(validator.type, " | ") 
			or validator.type
		table.insert(errors, `{path}: Expected type '{typeStr}', got '{typeof(value)}'`)
		return false, nil
	end
	-- Apply transformation if provided
	if validator.transform then
		local success, transformed = pcall(validator.transform, value)
		if success then
			value = transformed
		else
			table.insert(errors, `{path}: Transform failed: {transformed}`)
			return false, nil
		end
	end
	-- Numeric range validation
	if type(value) == "number" then
		if validator.min and value < validator.min then
			table.insert(errors, `{path}: Value {value} is below minimum {validator.min}`)
			return false, nil
		end
		if validator.max and value > validator.max then
			table.insert(errors, `{path}: Value {value} exceeds maximum {validator.max}`)
			return false, nil
		end
	end
	-- String pattern validation
	if type(value) == "string" and validator.pattern then
		if not string.match(value, validator.pattern) then
			table.insert(errors, `{path}: String does not match pattern '{validator.pattern}'`)
			return false, nil
		end
	end
	-- Enum validation
	if validator.enum then
		local found = false
		for _, enumValue in ipairs(validator.enum) do
			if value == enumValue then
				found = true
				break
			end
		end
		if not found then
			table.insert(errors, `{path}: Value must be one of {table.concat(validator.enum, ", ")}`)
			return false, nil
		end
	end
	-- Array validation
	if validator.arrayOf and isArray(value) then
		local validatedArray = {}
		for i, item in ipairs(value) do
			local success, validatedItem = validateField(
				item, 
				validator.arrayOf, 
				`{path}[{i}]`, 
				errors
			)
			if not success then
				return false, nil
			end
			validatedArray[i] = validatedItem
		end
		value = validatedArray
	end
	-- Map/Dictionary validation
	if validator.mapOf and type(value) == "table" then
		local validatedMap = {}
		for k, v in pairs(value) do
			-- Validate key if specified
			if validator.mapOf.key then
				local keySuccess = validateField(k, validator.mapOf.key, `{path}.key({k})`, errors)
				if not keySuccess then
					return false, nil
				end
			end
			-- Validate value
			if validator.mapOf.value then
				local success, validatedValue = validateField(
					v, 
					validator.mapOf.value, 
					`{path}[{tostring(k)}]`, 
					errors
				)
				if not success then
					return false, nil
				end
				validatedMap[k] = validatedValue
			else
				validatedMap[k] = v
			end
		end
		value = validatedMap
	end
	-- Custom validator function
	if validator.validator then
		local success, result = pcall(validator.validator, value)
		if not success or not result then
			local errorMsg = validator.description or "Custom validation failed"
			table.insert(errors, `{path}: {errorMsg}`)
			return false, nil
		end
	end
	return true, value
end

local function validateSchema(config: any, schema: Schema, path: string, errors: {string}): (boolean, any)
	if type(config) ~= "table" then
		table.insert(errors, `{path}: Expected a table, got '{typeof(config)}'`)
		return false, nil
	end

	local validated = {}
	local success = true

	for key, fieldSchema in pairs(schema) do
		local fieldPath = path == "" and key or `{path}.{key}`
		local value = config[key]

		-- Check if it's a nested schema or a field validator
		if fieldSchema.type then
			-- It's a field validator
			local fieldSuccess, validatedValue = validateField(
				value, 
				fieldSchema :: FieldValidator, 
				fieldPath, 
				errors
			)
			if fieldSuccess then
				validated[key] = validatedValue
			else
				success = false
			end
		else
			-- It's a nested schema
			local nestedSuccess, nestedValidated = validateSchema(
				value or {}, 
				fieldSchema :: Schema, 
				fieldPath, 
				errors
			)
			if nestedSuccess then
				validated[key] = nestedValidated
			else
				success = false
			end
		end
	end

	return success, validated
end

-- CONSTRUCTOR --

--[[
	Creates a new Filter instance.
	
	The Filter provides a way to validate
	complex configuration tables with detailed error reporting.
	
	@return Filter -- A new Filter instance
	
	Example:
	```lua
	local validator = Filter.new()
	```
]]
function Filter.new(): Filter
	local self: any = setmetatable({}, FilterMt)
	local private: FilterInternals = {
		schemas = {},
		errorCollector = {}
	}
	privateData[self] = private
	return self
end

-- BUILDER FUNCTIONS (Static) --

--[[
	Creates a field validator.
	
	@param fieldType string | {string} -- The expected type(s)
	@return FieldBuilder -- A field builder with chainable methods
	
	Example:
	```lua
	local Field = Filter.Field
	local schema = {
		name = Field("string"):Required(),
		age = Field("number"):Min(0):Max(120),
		email = Field("string"):Pattern("^[%w.]+@[%w.]+$"),
		role = Field("string"):Enum({"admin", "user", "guest"}):Default("user")
	}
	```
]]
function Filter.Field(fieldType: string | {string}): FieldBuilder
	local validator: FieldValidator = {
		type = fieldType,
		optional = true
	}
	-- Create a proxy that acts as both builder and validator
	local proxy = {}
	-- Builder methods
	function proxy:Required()
		validator.optional = false
		return self
	end

	function proxy:Optional(defaultValue: any)
		validator.optional = true
		validator.default = defaultValue
		return self
	end

	function proxy:Min(min: number)
		validator.min = min
		return self
	end

	function proxy:Max(max: number)
		validator.max = max
		return self
	end

	function proxy:Pattern(pattern: string)
		validator.pattern = pattern
		return self
	end

	function proxy:Enum(values: {any})
		validator.enum = values
		return self
	end

	function proxy:Transform(transform: (any) -> any)
		validator.transform = transform
		return self
	end

	function proxy:Validator(validatorFunc: (any) -> boolean, description: string?)
		validator.validator = validatorFunc
		validator.description = description
		return self
	end

	function proxy:ArrayOf(itemValidator: FieldBuilder | FieldValidator)
		validator.arrayOf = itemValidator
		return self
	end

	function proxy:MapOf(keyValidator: (FieldBuilder | FieldValidator)?, valueValidator: FieldBuilder | FieldValidator)
		validator.mapOf = {
			key = keyValidator,
			value = valueValidator
		}
		return self
	end

	function proxy:Default(value: any)
		validator.default = value
		return self
	end

	function proxy:Description(desc: string)
		validator.description = desc
		return self
	end

	-- Set up metatable to make proxy act as validator when accessed
	setmetatable(proxy, {
		__index = function(_, key)
			-- First check if it's a property of the validator
			local value = validator[key]
			if value ~= nil then
				return value
			end
			-- Then check if it's a method on proxy
			return rawget(proxy, key)
		end,
		__newindex = function(_, key, value)
			validator[key] = value
		end,
		__tostring = function()
			return "FieldValidator"
		end
	})
	return (proxy :: any)
end

-- PUBLIC METHODS --

--[[
	Defines a reusable schema that can be referenced by name.
	
	@param name string -- The name to register the schema under
	@param schema Schema -- The schema definition
	@return Filter -- Returns self for method chaining
	
	Example:
	```lua
	validator:DefineSchema("PlayerConfig", {
		name = Field("string"):Required(),
		level = Field("number"):Min(1):Max(100),
		inventory = Field("array"):ArrayOf(Field("string"))
	})
	```
]]
function FilterMt:DefineSchema(name: string, schema: Schema): Filter
	assert(type(name) == "string", `Schema name must be a string, got '{name}'`)
	assert(type(schema) == "table", `Schema must be a table, got '{schema}'`)
	privateData[self].schemas[name] = schema
	return self
end

--[[
	Validates a configuration against a schema.
	
	@param config any -- The configuration to validate
	@param schemaOrName Schema | string -- The schema or name of a defined schema
	@return boolean, any -- Success status and validated/transformed config or nil
	
	Example:
	```lua
	local success, validated = validator:Validate(userConfig, "PlayerConfig")
	if success then
		print("Config is valid!", validated)
	else
		print("Validation failed:", validator:GetErrors())
	end
	```
]]
function FilterMt:Validate(config: any, schemaOrName: Schema | string): (boolean, any)
	local private = privateData[self]
	local schema: Schema
	-- Resolve schema
	if type(schemaOrName) == "string" then
		schema = private.schemas[schemaOrName]
		assert(schema, `No schema defined with name '{schemaOrName}'`)
	else
		schema = schemaOrName
	end
	-- Clear previous errors
	private.errorCollector = {}
	-- Validate
	local success, validated = validateSchema(config, schema, "", private.errorCollector :: {string})
	if not success and #(private.errorCollector :: {string}) == 0 then
		table.insert(private.errorCollector :: {string}, "Validation failed for unknown reason")
	end
	return success, validated
end

--[[
	Validates a configuration in strict mode, throwing an error if validation fails.
	
	@param config any -- The configuration to validate
	@param schemaOrName Schema | string -- The schema or name of a defined schema
	@return any -- The validated and transformed configuration
	
	Example:
	```lua
	local validated = validator:ValidateStrict(userConfig, schema)
	-- Throws error if validation fails
	```
]]
function FilterMt:ValidateStrict(config: any, schemaOrName: Schema | string): any
	local success, validated = self:Validate(config, schemaOrName)
	if not success then
		local errors = self:GetErrors() or {"Unknown validation error"}
		error(`Config validation failed:\n{table.concat(errors, "\n")}`)
	end
	return validated
end

--[[
	Gets the errors from the last validation.
	
	@return {string}? -- Array of error messages or nil if no errors
	
	Example:
	```lua
	local errors = validator:GetErrors()
	if errors then
		for _, error in ipairs(errors) do
			warn(error)
		end
	end
	```
]]
function FilterMt:GetErrors(): {string}?
	local errors = privateData[self].errorCollector
	return errors and #errors > 0 and errors or nil
end

--[[
	Destroys the Filter instance and cleans up resources.
	
	Example:
	```lua
	validator:Destroy()
	validator = nil
	```
]]
function FilterMt:Destroy()
	local private = privateData[self]
	-- Clear all private variables...
	for k in pairs(private.schemas) do
		private.schemas[k] = nil
	end
	if private.errorCollector then
		table.clear(private.errorCollector)
	end
	-- Ensure metatable and private data entry is nil
	privateData[self] = nil
	setmetatable(self, nil)
end

-- Export the Field builder as a static method
Filter.Field = Filter.Field

return Filter