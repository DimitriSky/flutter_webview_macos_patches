require 'json'
require 'net/http'
require 'fileutils'

base, expected_mode, label = ARGV
abort 'usage: ruby scripts/capture_run.rb http://127.0.0.1:PORT MODE LABEL' unless base && expected_mode && label
uri = URI(base)
abort 'loopback HTTP only' unless uri.host == '127.0.0.1' && uri.scheme == 'http'
abort 'invalid label' unless label.match?(/\A[a-zA-Z0-9_-]+\z/)

def read_json(uri, path)
  Net::HTTP.start(uri.host, uri.port, open_timeout: 5, read_timeout: 5) do |http|
    response = http.get(path)
    abort "HTTP #{response.code}" unless response.code == '200'
    JSON.parse(response.body)
  end
end

state = read_json(uri, '/state')
# Preserve the build location within the lab without publishing machine paths.
native = state['native']
if native.is_a?(Hash) && native['bundlePath'].is_a?(String)
  native['bundlePath'] = native['bundlePath'].sub(%r{\A.*?/(build/)}, '\\1')
  native['bundlePath'] = File.basename(native['bundlePath']) if native['bundlePath'].start_with?('/')
end
abort "Expected #{expected_mode}, got #{state['mode']}" unless state['mode'] == expected_mode
matrix = read_json(uri, '/matrix')
safe = matrix.reject { |item| item['manualReason'] }
page = state.fetch('page')
combinations = page.fetch('combinations', {})
# Do not commit clipboard contents or text typed during a physical keyboard test.
page['values'] = page.fetch('values', {}).transform_values { |value| { 'length' => value.length } }
summary = {
  'mode' => state['mode'], 'run' => state['run'], 'keydowns' => page['keydowns'],
  'duplicates' => page['duplicates'], 'repeats' => page['repeats'],
  'restartRequired' => state['restartRequired'],
  'duplicateChords' => combinations.select { |_, value| value['duplicates'] > 0 },
  'matrixCases' => matrix.length, 'nonSystemCases' => safe.length,
  'unobserved' => safe.reject { |item| combinations.key?(item['browserChord']) }.map { |item| item['chord'] },
}
directory = File.expand_path('../evidence', __dir__)
FileUtils.mkdir_p(directory)
File.write(File.join(directory, "#{label}.json"), JSON.pretty_generate({ 'summary' => summary, 'state' => state }))
puts JSON.pretty_generate(summary.merge('unobservedCount' => summary['unobserved'].length,
                                        'unobserved' => summary['unobserved'].first(12)))
