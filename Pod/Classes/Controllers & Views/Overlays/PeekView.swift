//
//  PeekView.swift
//  Peek
//
//  Created by Shaps Benkau on 11/03/2018.
//

import UIKit

internal final class PeekSelectionView: UIView {
 
    internal override init(frame: CGRect){
        super.init(frame: frame)
        
        layer.cornerRadius = 3
        layer.borderColor = UIColor.primaryTint?.cgColor
        layer.borderWidth = 1.5
        layer.zPosition = 20
        backgroundColor = .clear
    }
    
    internal required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

internal protocol PeekViewDelegate: class {
    func viewModels(in peekView: PeekView) -> [UIView]
    func didSelect(viewModel: UIView, in peekView: PeekView)
    func showInsectorFor(viewModel: UIView, in peekView: PeekView)
    func didBeginDragging(in peekView: PeekView)
    func didEndDragging(in peekView: PeekView)
}

internal final class PeekView: UIView {
    
    internal weak var delegate: PeekViewDelegate?
    internal var allowsMultipleSelection: Bool = false
    
    private var viewModels: [UIView] = []
    internal private(set) var indexesForSelectedItems = IndexSet()
    
    private var isDragging: Bool = false
    private var feedbackGenerator: Any?
    private var observer: Any?
    
    @available(iOS 10.0, *)
    private func haptic() -> UIImpactFeedbackGenerator? {
        return feedbackGenerator as? UIImpactFeedbackGenerator
    }
    
    private lazy var panGesture: UIPanGestureRecognizer = {
        return UIPanGestureRecognizer(target: self, action: #selector(handlePan(gesture:)))
    }()
    
    private lazy var tapGesture: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(handleTap(gesture:)))
    }()
    
    private lazy var doubleTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gesture:)))
        gesture.numberOfTapsRequired = 2
        return gesture
    }()
    
    private lazy var primarySelectionView: PeekSelectionView = {
        let view = PeekSelectionView(frame: .zero)
        addSubview(view)
        return view
    }()
    
    internal init() {
        super.init(frame: .zero)
        
        addGestureRecognizer(panGesture)
        addGestureRecognizer(tapGesture)
        addGestureRecognizer(doubleTapGesture)
        tapGesture.require(toFail: doubleTapGesture)
        
        updateBackgroundColor(alpha: 0.5)
        
        observer = NotificationCenter.default.addObserver(forName: .UIContentSizeCategoryDidChange, object: nil, queue: .main) { [weak self] _ in
            // we have to add a delay to allow the app to finish updating its layout.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.refresh()
            }
        }
    }
    
    internal func refresh() {
        viewModels = delegate?.viewModels(in: self) ?? []
        
        if let index = indexesForSelectedItems.last {
            selectViewModel(at: index, animated: false)
        }
    }
    
    @objc private func handlePan(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            if #available(iOS 10.0, *) {
                feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                haptic()?.prepare()
            }
            
            updateBackgroundColor(alpha: 0.3)
            isDragging = true
            delegate?.didBeginDragging(in: self)
        case .changed:
            hitTest(at: gesture.location(in: gesture.view))
        default:
            isDragging = false
            delegate?.didEndDragging(in: self)
            updateBackgroundColor(alpha: 0.5)
            feedbackGenerator = nil
        }
    }
    
    @objc private func handleTap(gesture: UITapGestureRecognizer) {
        if gesture.state == .ended {
            if gesture === doubleTapGesture {
                guard let index = indexesForSelectedItems.last else { return }
                delegate?.showInsectorFor(viewModel: viewModels[index], in: self)
            } else {
                hitTest(at: gesture.location(in: gesture.view))
            }
        }
    }
    
    private func hitTest(at point: CGPoint) {
        for (index, model) in zip(viewModels.indices, viewModels) {
            let frame = model.frameInPeek(self)
            
            if !indexesForSelectedItems.contains(index), frame.contains(point) {
                selectViewModel(at: index, animated: true)
                delegate?.didSelect(viewModel: model, in: self)
                break
            }
        }
    }
    
    private func selectViewModel(at index: Int, animated: Bool) {
        /**
         When isDragging, replace the last index only
         Otherwise, move the last index into the first, then replace the last index
         */
        
        indexesForSelectedItems.removeAll()
        indexesForSelectedItems.insert(index)
        let frame = viewModels[index].frameInPeek(self)
        
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.primarySelectionView.frame = frame
            }
        } else {
            primarySelectionView.frame = frame
        }
    }
    
    private func updateBackgroundColor(alpha: CGFloat) {
        backgroundColor = UIColor(white: 0, alpha: alpha)
        
        let animation = CATransition()
        animation.type = kCATransitionFade
        animation.duration = 0.1
        layer.add(animation, forKey: "fade")
    }
    
    internal required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}