// SPDX-License-Identifier: MIT
// forgefmt: disable-start
// TODO Consider replacing these OpenZeppelin math methods with optimized solmate (or solady) ones.
pragma solidity ^0.8.0;

/**
 * @dev This library defines the `History` struct, for checkpointing values as they change at different points in
 * time, and later looking up past values by block timestamp. See {Votes} as an example.
 *
 * To create a history of checkpoints define a variable type `Checkpoints.History` in your contract, and store a new
 * checkpoint for the current transaction block using the {push} function.
 *
 * @dev This was created by modifying then running the OpenZeppelin `Checkpoints.js` script, which generated a version
 * of this library that uses a 64 bit `timestamp` and 128 bit `quantity` field in the `Checkpoint` struct. The struct
 * was then modified to add a 64 bit `expiration` field. For simplicity, safe cast and math methods were inlined from
 * the OpenZeppelin versions at the same commit. We disable forge-fmt for this file to simplify diffing against the
 * original OpenZeppelin version: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/d00acef4059807535af0bd0dd0ddf619747a044b/contracts/utils/Checkpoints.sol
 */
library Checkpoints {
    struct History {
        Checkpoint[] _checkpoints;
    }

    struct Checkpoint {
        uint64 timestamp;
        uint128 quantity;
    }

    /**
     * @dev Returns the quantity at a given block timestamp. If a checkpoint is not available at that block, the closest one
     * before it is returned, or zero otherwise.
     */
    function getAtTimestamp(History storage self, uint256 timestamp) internal view returns (uint256) {
        require(timestamp < block.timestamp, "Checkpoints: timestamp is not in the past");
        uint64 _timestamp = toUint64(timestamp);

        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, _timestamp, 0, len);
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1).quantity;
    }

    /**
     * @dev Returns the quantity at a given block timestamp. If a checkpoint is not available at that block, the closest one
     * before it is returned, or zero otherwise. Similar to {upperLookup} but optimized for the case when the searched
     * checkpoint is probably "recent", defined as being among the last sqrt(N) checkpoints where N is the timestamp of
     * checkpoints.
     */
    function getAtProbablyRecentTimestamp(History storage self, uint256 timestamp) internal view returns (uint256) {
        require(timestamp < block.timestamp, "Checkpoints: timestamp is not in the past");
        uint64 _timestamp = toUint64(timestamp);

        uint256 len = self._checkpoints.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - sqrt(len);
            if (_timestamp < _unsafeAccess(self._checkpoints, mid).timestamp) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, _timestamp, low, high);

        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1).quantity;
    }

    /**
     * @dev Pushes a quantity onto a History so that it is stored as the checkpoint for the current block.
     *
     * Returns previous quantity and new quantity.
     */
    function push(History storage self, uint256 quantity) internal returns (uint256, uint256) {
        return _insert(self._checkpoints, toUint64(block.timestamp), toUint128(quantity));
    }

    /**
     * @dev Pushes a quantity onto a History, by updating the latest quantity using binary operation `op`. The new
     * quantity will be set to `op(latest, delta)`.
     *
     * Returns previous quantity and new quantity.
     */
    function push(
        History storage self,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) internal returns (uint256, uint256) {
        return push(self, op(latest(self), delta));
    }

    /**
     * @dev Returns the quantity in the most recent checkpoint, or zero if there are no checkpoints.
     */
    function latest(History storage self) internal view returns (uint128) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1).quantity;
    }

    /**
     * @dev Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the timestamp and
     * quantity in the most recent checkpoint.
     */
    function latestCheckpoint(History storage self)
        internal
        view
        returns (
            bool exists,
            uint64 timestamp,
            uint128 quantity
        )
    {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, 0);
        } else {
            Checkpoint memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt.timestamp, ckpt.quantity);
        }
    }

    /**
     * @dev Returns the number of checkpoints.
     */
    function length(History storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @dev Pushes a (`timestamp`, `quantity`) pair into an ordered list of checkpoints, either by inserting a new
     * checkpoint, or by updating the last one.
     */
    function _insert(
        Checkpoint[] storage self,
        uint64 timestamp,
        uint128 quantity
    ) private returns (uint128, uint128) {
        uint256 pos = self.length;

        if (pos > 0) {
            // Copying to memory is important here.
            Checkpoint memory last = _unsafeAccess(self, pos - 1);

            // Checkpoints timestamps must be increasing.
            require(last.timestamp <= timestamp, "Checkpoint: invalid timestamp");

            // Update or push new checkpoint
            if (last.timestamp == timestamp) {
                _unsafeAccess(self, pos - 1).quantity = quantity;
            } else {
                self.push(Checkpoint({timestamp: timestamp, quantity: quantity}));
            }
            return (last.quantity, quantity);
        } else {
            self.push(Checkpoint({timestamp: timestamp, quantity: quantity}));
            return (0, quantity);
        }
    }

    /**
     * @dev Return the index of the oldest checkpoint whose timestamp is greater than the search timestamp, or `high`
     * if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and exclusive
     * `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _upperBinaryLookup(
        Checkpoint[] storage self,
        uint64 timestamp,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = average(low, high);
            if (_unsafeAccess(self, mid).timestamp > timestamp) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev Return the index of the oldest checkpoint whose timestamp is greater or equal than the search timestamp, or
     * `high` if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and
     * exclusive `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _lowerBinaryLookup(
        Checkpoint[] storage self,
        uint64 timestamp,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = average(low, high);
            if (_unsafeAccess(self, mid).timestamp < timestamp) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    function _unsafeAccess(Checkpoint[] storage self, uint256 pos)
        private
        pure
        returns (Checkpoint storage result)
    {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) private pure returns (uint256) {
        return (a & b) + (a ^ b) / 2; // (a + b) / 2 can overflow.
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) private pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) private pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     */
    function toUint128(uint256 value) private pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     */
    function toUint64(uint256 value) private pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }
}
