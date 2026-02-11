//
//  ScrollStateResettable.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import Foundation

@MainActor
protocol ScrollStateResettable: AnyObject {
    func resetScrollState()
}
