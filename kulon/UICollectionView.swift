//
// Created by Артмеий Шлесберг on 16/06/2017.
// Copyright (c) 2017 Jufy. All rights reserved.
//

import Foundation
import UIKit

extension UICollectionView {

    func dequeueReusableCellOfType<CellType: UICollectionViewCell>(_ type: CellType.Type, for indexPath: IndexPath) -> CellType {
        let cellName = String(describing: type)
        register(CellType.self, forCellWithReuseIdentifier: cellName)
        return dequeueReusableCell(withReuseIdentifier: cellName, for: indexPath) as! CellType
    }
    
    func dequeueReusableSupplementaryCellOfType<CellType: UICollectionViewCell>(_ type: CellType.Type, for indexPath: IndexPath, kind: String) -> CellType {
        let cellName = String(describing: type)
        register(CellType.self, forSupplementaryViewOfKind: kind, withReuseIdentifier: cellName)
        return dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: cellName, for: indexPath) as! CellType
    }
    
}
