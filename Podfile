platform :ios, '17.4'

target 'VTM' do
  use_frameworks!

  # Google ML Kit Translate - primary translation engine (59 languages)
  pod 'GoogleMLKit/Translate', '~> 6.0'

end

post_install do |installer|
  # Fix 1: Exclude x86_64 from simulator builds (only need arm64 for Apple Silicon Macs)
  # whisper.framework and onnxruntime.framework are arm64-only
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'x86_64'
    end
  end

  # Fix 2: Fix MLKitTranslate resource bundle path
  # Pre-built framework pods don't have resources in PODS_CONFIGURATION_BUILD_DIR
  resources_script = File.join(installer.sandbox.root, 'Target Support Files', 'Pods-VTM', 'Pods-VTM-resources.sh')
  if File.exist?(resources_script)
    content = File.read(resources_script)
    content.gsub!('${PODS_CONFIGURATION_BUILD_DIR}/MLKitTranslate/MLKitTranslate_resource.bundle',
                   '${PODS_ROOT}/MLKitTranslate/Frameworks/MLKitTranslate.framework/MLKitTranslate_resource.bundle')
    File.write(resources_script, content)
  end

  # Fix 3: Fix resources xcfilelist input paths
  %w[Debug Release].each do |config|
    xcfilelist = File.join(installer.sandbox.root, 'Target Support Files', 'Pods-VTM', "Pods-VTM-resources-#{config}-input-files.xcfilelist")
    if File.exist?(xcfilelist)
      content = File.read(xcfilelist)
      content.gsub!('${PODS_CONFIGURATION_BUILD_DIR}/MLKitTranslate/MLKitTranslate_resource.bundle',
                     '${PODS_ROOT}/MLKitTranslate/Frameworks/MLKitTranslate.framework/MLKitTranslate_resource.bundle')
      File.write(xcfilelist, content)
    end
  end
end
