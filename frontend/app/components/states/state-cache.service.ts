// -- copyright
// OpenProject is a project management system.
// Copyright (C) 2012-2018 the OpenProject Foundation (OPF)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See doc/COPYRIGHT.rdoc for more details.
// ++

import {InputState, MultiInputState, State} from 'reactivestates';

export abstract class StateCacheService<T> {
  private cacheDurationInMs:number;

  constructor(private holdValuesForSeconds:number = 120) {
    this.cacheDurationInMs = holdValuesForSeconds * 1000;
  }

  public state(id:string):State<T> {
    return this.multiState.get(id);
  }

  /**
   * Touch the current state to fire subscribers.
   */
  public touch(id:string):void {
    const state = this.multiState.get(id);
    state.putValue(state.value, 'Touching the state');
  }

  /**
   * Update the value due to application changes.
   *
   * @param id The value's identifier.
   * @param val<T> The value.
   */
  public updateValue(id:string, val:T) {
    this.multiState.get(id).putValue(val);
  }

  /**
   * Clear a set of cached states.
   * @param ids
   */
  public clearSome(...ids:string[]) {
    ids.forEach(id => this.multiState.get(id).clear());
  }

  /**
   * Require the value to be loaded either when forced or the value is stale
   * according to the cache interval specified for this service.
   *
   * @param id The value's identifier.
   * @param force Load the value anyway.
   */
  public async require(id:string, force:boolean = false):Promise<T> {
    const state = this.multiState.get(id);

    // Refresh when stale or being forced
    if (this.stale(state) || force) {
      return this.load(id);
    }

    return Promise.resolve(state.value as T);
  }

  /**
   * Require the states of the given ids to be loaded if they're empty or stale,
   * or all when force is given.
   * @param ids Ids to require
   * @param force Load the values anyway
   * @return {Promise<undefined>} An empty promise to mark when the set of states is filled.
   */
  public async requireAll(ids:string[], force:boolean = false):Promise<undefined> {
    let idsToRequest:string[];

    if (force) {
      idsToRequest = ids;
    } else {
      idsToRequest = ids.filter((id:string) => this.stale(this.multiState.get(id)));
    }

    if (idsToRequest.length === 0) {
      return Promise.resolve(undefined);
    }

    return this.loadAll(idsToRequest);
  }

  /**
   * Returns whether the state
   * @param state
   * @return {boolean}
   */
  protected stale(state:InputState<T>):boolean {
    return state.isPristine() || state.isValueOlderThan(this.cacheDurationInMs);
  }

  /**
   * Returns the internal state object
   */
  protected abstract get multiState():MultiInputState<T>;

  /**
   * Load a single value into the cache state.
   * Subclassses need to ensure it gets loaded and resolve or reject the promise
   * @param id The identifier of the value object of type T.
   */
  protected abstract load(id:string):Promise<T>;

  /**
   * Load a set of required values, fill the results into the appropriate states
   * and return a promise when all values are inserted.
   */
  protected abstract loadAll(ids:string[]):Promise<undefined>;
}
