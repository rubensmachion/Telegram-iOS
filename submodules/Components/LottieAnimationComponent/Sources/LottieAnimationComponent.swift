import Foundation
import ComponentFlow
import Lottie
import AppBundle
import HierarchyTrackingLayer

public final class LottieAnimationComponent: Component {
    public struct Animation: Equatable {
        public enum Mode: Equatable {
            case still
            case animating(loop: Bool)
            case animateTransitionFromPrevious
        }
        
        public var name: String
        public var mode: Mode
        public var colors: [String: UIColor]
        
        public init(name: String, colors: [String: UIColor], mode: Mode) {
            self.name = name
            self.colors = colors
            self.mode = mode
        }
    }
    
    public let animation: Animation
    public let tag: AnyObject?
    public let size: CGSize?
    
    public init(animation: Animation, tag: AnyObject? = nil, size: CGSize?) {
        self.animation = animation
        self.tag = tag
        self.size = size
    }
    
    public func tagged(_ tag: AnyObject?) -> LottieAnimationComponent {
        return LottieAnimationComponent(
            animation: self.animation,
            tag: tag,
            size: self.size
        )
    }

    public static func ==(lhs: LottieAnimationComponent, rhs: LottieAnimationComponent) -> Bool {
        if lhs.animation != rhs.animation {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }
    
    public final class View: UIView, ComponentTaggedView {
        private var component: LottieAnimationComponent?
        
        private var colorCallbacks: [LOTColorValueCallback] = []
        private var animationView: LOTAnimationView?
        private var didPlayToCompletion: Bool = false
        
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        
        override init(frame: CGRect) {
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                guard let strongSelf = self, let animationView = strongSelf.animationView else {
                    return
                }
                if animationView.loopAnimation {
                    animationView.play()
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        public func playOnce() {
            guard let animationView = self.animationView else {
                return
            }

            animationView.stop()
            animationView.loopAnimation = false
            animationView.play { _ in
            }
        }
        
        func update(component: LottieAnimationComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            var updatePlayback = false
            
            if self.component?.animation != component.animation {
                if let animationView = self.animationView {
                    if case .animateTransitionFromPrevious = component.animation.mode, !animationView.isAnimationPlaying, !self.didPlayToCompletion {
                        animationView.play { _ in
                        }
                    }
                }
                
                if let animationView = self.animationView, animationView.isAnimationPlaying {
                    animationView.completionBlock = { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.didPlayToCompletion = true
                        let _ = strongSelf.update(component: component, availableSize: availableSize, transition: transition)
                    }
                    animationView.loopAnimation = false
                } else {
                    self.component = component
                    
                    self.animationView?.removeFromSuperview()
                    self.didPlayToCompletion = false
                    
                    if let url = getAppBundle().url(forResource: component.animation.name, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
                        let view = LOTAnimationView(model: composition, in: getAppBundle())
                        switch component.animation.mode {
                        case .still, .animateTransitionFromPrevious:
                            view.loopAnimation = false
                        case let .animating(loop):
                            view.loopAnimation = loop
                        }
                        view.animationSpeed = 1.0
                        view.backgroundColor = .clear
                        view.isOpaque = false
                        
                        //view.logHierarchyKeypaths()
                        
                        for (key, value) in component.animation.colors {
                            let colorCallback = LOTColorValueCallback(color: value.cgColor)
                            self.colorCallbacks.append(colorCallback)
                            view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                        }
                        
                        self.animationView = view
                        self.addSubview(view)
                        
                        updatePlayback = true
                    }
                }
            }
            
            var animationSize = CGSize()
            if let animationView = self.animationView, let sceneModel = animationView.sceneModel {
                animationSize = sceneModel.compBounds.size
            }
            if let customSize = component.size {
                animationSize = customSize
            }
            
            let size = CGSize(width: min(animationSize.width, availableSize.width), height: min(animationSize.height, availableSize.height))
            
            if let animationView = self.animationView {
                animationView.frame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: floor((size.height - animationSize.height) / 2.0)), size: animationSize)
                
                if updatePlayback {
                    if case .animating = component.animation.mode {
                        if !animationView.isAnimationPlaying {
                            animationView.play { _ in
                            }
                        }
                    } else {
                        if animationView.isAnimationPlaying {
                            animationView.stop()
                        }
                    }
                }
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
