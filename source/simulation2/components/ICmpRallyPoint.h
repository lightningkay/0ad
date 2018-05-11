/* Copyright (C) 2018 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * 0 A.D. is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with 0 A.D.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef INCLUDED_ICMPRALLYPOINT
#define INCLUDED_ICMPRALLYPOINT

#include "simulation2/system/Interface.h"

class CFixedVector2D;

/**
 * Rally point.
 */
class ICmpRallyPoint : public IComponent
{
public:
	virtual bool HasPositions() = 0;

	virtual CFixedVector2D GetFirstPosition() = 0;

	DECLARE_INTERFACE_TYPE(RallyPoint)
};

#endif // INCLUDED_ICMPRALLYPOINT
