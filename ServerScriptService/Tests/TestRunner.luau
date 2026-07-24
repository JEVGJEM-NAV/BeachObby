--!strict

export type TestCallback = () -> ()

type TestCase = {
	name: string,
	callback: TestCallback,
}

local tests: { TestCase } = {}
local registeredNames: { [string]: boolean } = {}

local TestRunner = {}

function TestRunner.test(name: string, callback: TestCallback)
	assert(name ~= "", "Test name must not be empty")
	assert(not registeredNames[name], string.format("Test %q is already registered", name))

	registeredNames[name] = true
	table.insert(tests, {
		name = name,
		callback = callback,
	})
end

function TestRunner.assertEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(message or string.format("Expected %s, got %s", tostring(expected), tostring(actual)), 2)
	end
end

function TestRunner.assertTrue(value: any, message: string?)
	if value ~= true then
		error(message or string.format("Expected true, got %s", tostring(value)), 2)
	end
end

function TestRunner.assertFalse(value: any, message: string?)
	if value ~= false then
		error(message or string.format("Expected false, got %s", tostring(value)), 2)
	end
end

function TestRunner.assertError(callback: TestCallback, message: string?)
	local succeeded = pcall(callback)

	if succeeded then
		error(message or "Expected callback to raise an error", 2)
	end
end

function TestRunner.run(): (number, number)
	local passed = 0
	local failed = 0

	for _, testCase in tests do
		local succeeded, failureMessage = pcall(testCase.callback)

		if succeeded then
			passed += 1
			print(string.format("[PASS] %s", testCase.name))
		else
			failed += 1
			print(string.format("[FAIL] %s: %s", testCase.name, tostring(failureMessage)))
		end
	end

	print(string.format("TEST %d passed, %d failed", passed, failed))

	if failed > 0 then
		error(string.format("Automated tests failed: %d test(s) failed", failed), 0)
	end

	return passed, failed
end

return table.freeze(TestRunner)
