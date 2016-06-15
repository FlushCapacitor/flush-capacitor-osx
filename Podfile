platform :osx, '10.8'
xcodeproj 'FlushCapacitor/FlushCapacitor.xcodeproj'

def all_pods
  pod 'Reachability' # tonymillion's ARC modernized
  pod 'SocketRocket'
end

target 'FlushCapacitor' do
  all_pods
  use_frameworks!
end

target 'FlushCapacitorTests' do
  all_pods
  use_frameworks!
end

